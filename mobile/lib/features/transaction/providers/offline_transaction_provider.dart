import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/data/services/sync_service.dart';
import 'package:family_finance_app/core/network/network_status.dart';

// 本地数据库 Provider
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

// 同步服务 Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

// 离线交易状态
final offlineTransactionProvider = StateNotifierProvider<OfflineTransactionNotifier, OfflineTransactionState>((ref) {
  return OfflineTransactionNotifier(
    ref.read(localDatabaseProvider),
    ref.read(syncServiceProvider),
    ref.read(networkStatusProvider),
  );
});

class OfflineTransactionState {
  final List<Map<String, dynamic>> pendingTransactions;
  final bool isSyncing;
  final String? error;
  
  OfflineTransactionState({
    this.pendingTransactions = const [],
    this.isSyncing = false,
    this.error,
  });
  
  OfflineTransactionState copyWith({
    List<Map<String, dynamic>>? pendingTransactions,
    bool? isSyncing,
    String? error,
  }) {
    return OfflineTransactionState(
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
    );
  }
}

class OfflineTransactionNotifier extends StateNotifier<OfflineTransactionState> {
  final LocalDatabase _db;
  final SyncService _sync;
  final NetworkStatus _networkStatus;
  
  OfflineTransactionNotifier(this._db, this._sync, this._networkStatus) 
      : super(OfflineTransactionState()) {
    _loadPendingTransactions();
  }
  
  Future<void> _loadPendingTransactions() async {
    try {
      final transactions = await _db.getTransactions(limit: 100);
      state = state.copyWith(pendingTransactions: transactions);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> createTransaction(Map<String, dynamic> data) async {
    try {
      // 添加到本地数据库
      data['is_synced'] = 0;
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();
      
      await _db.insertTransaction(data);
      
      // 添加同步日志
      await _db.addSyncLog('transactions', data['id'] ?? 0, 'create', data.toString());
      
      // 重新加载列表
      await _loadPendingTransactions();
      
      // 如果在线，立即同步
      if (_networkStatus == NetworkStatus.online) {
        await syncPendingTransactions();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> updateTransaction(int id, Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      
      await _db.updateTransaction(id, data);
      
      // 添加同步日志
      await _db.addSyncLog('transactions', id, 'update', data.toString());
      
      // 重新加载列表
      await _loadPendingTransactions();
      
      // 如果在线，立即同步
      if (_networkStatus == NetworkStatus.online) {
        await syncPendingTransactions();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> deleteTransaction(int id) async {
    try {
      await _db.deleteTransaction(id);
      
      // 添加同步日志
      await _db.addSyncLog('transactions', id, 'delete', null);
      
      // 重新加载列表
      await _loadPendingTransactions();
      
      // 如果在线，立即同步
      if (_networkStatus == NetworkStatus.online) {
        await syncPendingTransactions();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> syncPendingTransactions() async {
    if (state.isSyncing) return;
    
    state = state.copyWith(isSyncing: true);
    
    try {
      await _sync.syncAll();
      await _loadPendingTransactions();
      state = state.copyWith(isSyncing: false);
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
  
  Future<void> refreshFromServer() async {
    if (_networkStatus != NetworkStatus.online) return;
    
    state = state.copyWith(isSyncing: true);
    
    try {
      await _sync.syncAll();
      await _loadPendingTransactions();
      state = state.copyWith(isSyncing: false);
    } catch (e) {
      state = state.copyWith(isSyncing: false, error: e.toString());
    }
  }
}
