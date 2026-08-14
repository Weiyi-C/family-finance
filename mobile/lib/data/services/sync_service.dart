import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_app/core/network/network_status.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/data/services/api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  
  final LocalDatabase _db = LocalDatabase();
  final ApiService _api = ApiService();
  
  bool _isSyncing = false;
  
  SyncService._internal();

  /// 同步离线注册
  Future<bool> syncRegistration(ApiService api, LocalDatabase db) async {
    final pendingUser = await db.getPendingLocalUser();
    if (pendingUser == null) return true;

    try {
      final data = await api.syncRegister(
        clientId: pendingUser['local_id'] as String,
        phone: pendingUser['phone'] as String,
        passwordHash: pendingUser['password_hash'] as String,
        nickname: (pendingUser['nickname'] as String?) ?? '',
      );

      final serverId = data['user_id']?.toString();
      final familyId = data['family_id']?.toString();

      await db.updateLocalUserStatus(
        pendingUser['local_id'] as String,
        'SYNCED',
        serverId: serverId,
        familyId: familyId,
      );

      if (serverId != null) {
        await db.insertIdMapping({
          'local_id': pendingUser['local_id'] as String,
          'server_id': serverId,
          'entity_type': 'user',
          'synced_at': DateTime.now().millisecondsSinceEpoch,
        });
      }

      final syncItems = await db.getPendingSyncItems();
      for (final item in syncItems) {
        await db.updateSyncStatus(item['id'] as int, 'DONE');
      }

      return true;
    } catch (e) {
      print('Registration sync failed: $e');
      return false;
    }
  }

  /// 同步所有数据
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(isSyncing: true);
    }
    
    _isSyncing = true;
    final conflicts = <SyncConflict>[];
    
    try {
      // 0. 先同步离线注册
      final prefs = await SharedPreferences.getInstance();
      final isOfflineUser = prefs.getBool('is_offline_user') ?? false;
      if (isOfflineUser) {
        final registered = await syncRegistration(_api, _db);
        if (!registered) {
          _isSyncing = false;
          return SyncResult(success: false, error: '注册同步失败，请检查网络');
        }
      }

      // 1. 推送本地更改
      await _pushLocalChanges();
      
      // 2. 拉取服务器数据并检测冲突
      final serverConflicts = await _pullAndDetectConflicts();
      conflicts.addAll(serverConflicts);
      
      // 3. 标记已同步的记录
      await _markSynced();
      
      _isSyncing = false;
      return SyncResult(
        success: true,
        conflicts: conflicts,
      );
    } catch (e) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// 推送本地更改到服务器
  Future<void> _pushLocalChanges() async {
    final logs = await _db.getUnsyncedLogs();
    
    for (final log in logs) {
      try {
        final table = log['table_name'] as String;
        final recordId = log['record_id'] as int;
        final action = log['action'] as String;
        
        switch (table) {
          case 'transactions':
            if (action == 'create') {
              final txn = await _getLocalTransaction(recordId);
              if (txn != null) {
                await _api.createTransaction(txn);
              }
            } else if (action == 'update') {
              final txn = await _getLocalTransaction(recordId);
              if (txn != null) {
                await _api.updateTransaction(recordId, txn);
              }
            } else if (action == 'delete') {
              await _api.deleteTransaction(recordId);
            }
            break;
        }
        
        await _db.markSynced(log['id'] as int);
      } catch (e) {
        // 推送失败，保留日志等待下次同步
        print('Push error for log ${log['id']}: $e');
      }
    }
  }
  
  /// 拉取服务器数据并检测冲突
  Future<List<SyncConflict>> _pullAndDetectConflicts() async {
    final conflicts = <SyncConflict>[];
    
    try {
      // 拉取服务器交易数据
      final serverData = await _api.getTransactions(page: 1, pageSize: 100);
      final serverTransactions = serverData['items'] as List;
      
      for (final serverTxn in serverTransactions) {
        final serverMap = Map<String, dynamic>.from(serverTxn);
        final serverId = serverMap['id'] as int;
        
        // 获取本地数据
        final localTxn = await _getLocalTransaction(serverId);
        
        if (localTxn != null) {
          // 检测冲突
          final conflict = _detectConflict(serverId, localTxn, serverMap);
          if (conflict != null) {
            conflicts.add(conflict);
          } else {
            // 无冲突，更新本地数据
            await _db.updateTransaction(serverId, serverMap);
          }
        } else {
          // 本地不存在，直接插入
          await _db.insertTransaction(serverMap);
        }
      }
    } catch (e) {
      print('Pull error: $e');
    }
    
    return conflicts;
  }
  
  /// 检测冲突
  SyncConflict? _detectConflict(
    int recordId,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) {
    // 比较关键字段
    final criticalFields = ['amount', 'type', 'transaction_time'];
    final compareFields = [...criticalFields, 'merchant_name', 'description', 'category_id'];
    
    final conflictingFields = <String>[];
    
    for (final field in compareFields) {
      if (localData[field]?.toString() != serverData[field]?.toString()) {
        conflictingFields.add(field);
      }
    }
    
    if (conflictingFields.isEmpty) {
      return null; // 无冲突
    }
    
    return SyncConflict(
      tableName: 'transactions',
      recordId: recordId,
      localData: localData,
      serverData: serverData,
      conflictingFields: conflictingFields,
      detectedAt: DateTime.now(),
    );
  }
  
  /// 获取本地交易数据
  Future<Map<String, dynamic>?> _getLocalTransaction(int id) async {
    final results = await _db.getTransactions(limit: 1);
    if (results.isEmpty) return null;
    return results.first;
  }
  
  /// 标记已同步记录
  Future<void> _markSynced() async {
    final logs = await _db.getUnsyncedLogs();
    for (final log in logs) {
      await _db.markSynced(log['id'] as int);
    }
  }
  
  bool get isSyncing => _isSyncing;
}

class SyncResult {
  final bool success;
  final bool isSyncing;
  final List<SyncConflict> conflicts;
  final String? error;
  
  SyncResult({
    this.success = false,
    this.isSyncing = false,
    this.conflicts = const [],
    this.error,
  });
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

final autoSyncProvider = Provider<void>((ref) {
  final networkStatus = ref.watch(networkStatusProvider);
  final syncService = SyncService();

  if (networkStatus == NetworkStatus.online) {
    Future.microtask(() => syncService.syncAll());
  }
});
