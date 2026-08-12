import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/features/transaction/providers/offline_transaction_provider.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

enum ConflictResolution {
  serverWins,    // 服务器数据优先
  clientWins,    // 本地数据优先
  manual,        // 手动解决
  merge,         // 自动合并（不同字段）
}

class SyncConflict {
  final String tableName;
  final int recordId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final List<String> conflictingFields;
  final DateTime detectedAt;
  
  SyncConflict({
    required this.tableName,
    required this.recordId,
    required this.localData,
    required this.serverData,
    required this.conflictingFields,
    required this.detectedAt,
  });
}

class ConflictResolutionResult {
  final int conflictId;
  final ConflictResolution resolution;
  final Map<String, dynamic>? mergedData;
  
  ConflictResolutionResult({
    required this.conflictId,
    required this.resolution,
    this.mergedData,
  });
}

final conflictProvider = StateNotifierProvider<ConflictNotifier, ConflictState>((ref) {
  return ConflictNotifier(
    ref.read(localDatabaseProvider),
    ref.read(apiServiceProvider),
  );
});

class ConflictState {
  final List<SyncConflict> pendingConflicts;
  final bool isResolving;
  final String? error;
  
  ConflictState({
    this.pendingConflicts = const [],
    this.isResolving = false,
    this.error,
  });
  
  ConflictState copyWith({
    List<SyncConflict>? pendingConflicts,
    bool? isResolving,
    String? error,
  }) {
    return ConflictState(
      pendingConflicts: pendingConflicts ?? this.pendingConflicts,
      isResolving: isResolving ?? this.isResolving,
      error: error,
    );
  }
}

class ConflictNotifier extends StateNotifier<ConflictState> {
  final LocalDatabase _db;
  final ApiService _api;
  
  ConflictNotifier(this._db, this._api) : super(ConflictState());
  
  /// 检测冲突：比较本地和服务器数据
  Future<SyncConflict?> detectConflict(
    String tableName,
    int recordId,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) async {
    final conflictingFields = <String>[];
    
    // 比较关键字段
    final criticalFields = ['amount', 'type', 'category_id', 'transaction_time'];
    final compareFields = [...criticalFields, 'merchant_name', 'description', 'payment_account_id'];
    
    for (final field in compareFields) {
      if (localData[field] != serverData[field]) {
        conflictingFields.add(field);
      }
    }
    
    if (conflictingFields.isEmpty) {
      return null; // 无冲突
    }
    
    return SyncConflict(
      tableName: tableName,
      recordId: recordId,
      localData: localData,
      serverData: serverData,
      conflictingFields: conflictingFields,
      detectedAt: DateTime.now(),
    );
  }
  
  /// 自动解决冲突（非关键字段）
  Future<Map<String, dynamic>?> autoResolve(SyncConflict conflict) async {
    // 检查是否包含关键字段冲突
    final criticalFields = ['amount', 'type', 'transaction_time'];
    final hasCriticalConflict = conflict.conflictingFields.any(
      (field) => criticalFields.contains(field),
    );
    
    if (hasCriticalConflict) {
      // 关键字段冲突，需要手动解决
      return null;
    }
    
    // 非关键字段冲突，使用"最后修改 wins"策略
    final localUpdated = DateTime.tryParse(conflict.localData['updated_at'] ?? '');
    final serverUpdated = DateTime.tryParse(conflict.serverData['updated_at'] ?? '');
    
    if (localUpdated != null && serverUpdated != null) {
      if (localUpdated.isAfter(serverUpdated)) {
        return conflict.localData; // 本地更新
      } else {
        return conflict.serverData; // 服务器更新
      }
    }
    
    // 无法判断，默认服务器优先
    return conflict.serverData;
  }
  
  /// 手动解决冲突
  Future<void> resolveManually(
    SyncConflict conflict,
    ConflictResolution resolution, {
    Map<String, dynamic>? mergedData,
  }) async {
    state = state.copyWith(isResolving: true);
    
    try {
      Map<String, dynamic> finalData;
      
      switch (resolution) {
        case ConflictResolution.serverWins:
          finalData = conflict.serverData;
          break;
        case ConflictResolution.clientWins:
          finalData = conflict.localData;
          break;
        case ConflictResolution.merge:
          finalData = mergedData ?? conflict.localData;
          break;
        case ConflictResolution.manual:
          finalData = mergedData ?? conflict.localData;
          break;
      }
      
      // 更新本地数据库
      await _db.updateTransaction(conflict.recordId, finalData);
      
      // 如果选择客户端数据，推送到服务器
      if (resolution == ConflictResolution.clientWins || 
          resolution == ConflictResolution.merge) {
        await _api.updateTransaction(conflict.recordId, finalData);
      }
      
      // 从待解决列表中移除
      state = state.copyWith(
        pendingConflicts: state.pendingConflicts.where(
          (c) => c.recordId != conflict.recordId,
        ).toList(),
        isResolving: false,
      );
    } catch (e) {
      state = state.copyWith(isResolving: false, error: e.toString());
    }
  }
  
  /// 批量解决冲突（全部使用服务器数据）
  Future<void> resolveAllServerWins() async {
    state = state.copyWith(isResolving: true);
    
    try {
      for (final conflict in state.pendingConflicts) {
        await _db.updateTransaction(conflict.recordId, conflict.serverData);
      }
      
      state = state.copyWith(
        pendingConflicts: [],
        isResolving: false,
      );
    } catch (e) {
      state = state.copyWith(isResolving: false, error: e.toString());
    }
  }
  
  /// 批量解决冲突（全部使用本地数据）
  Future<void> resolveAllClientWins() async {
    state = state.copyWith(isResolving: true);
    
    try {
      for (final conflict in state.pendingConflicts) {
        await _api.updateTransaction(conflict.recordId, conflict.localData);
      }
      
      state = state.copyWith(
        pendingConflicts: [],
        isResolving: false,
      );
    } catch (e) {
      state = state.copyWith(isResolving: false, error: e.toString());
    }
  }
  
  /// 添加冲突到待解决列表
  void addConflict(SyncConflict conflict) {
    state = state.copyWith(
      pendingConflicts: [...state.pendingConflicts, conflict],
    );
  }
  
  /// 清除所有冲突
  void clearConflicts() {
    state = state.copyWith(pendingConflicts: []);
  }
}
