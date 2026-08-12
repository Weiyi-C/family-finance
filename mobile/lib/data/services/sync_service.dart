import '../database/local_database.dart';
import '../services/api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  
  final LocalDatabase _db = LocalDatabase();
  final ApiService _api = ApiService();
  
  bool _isSyncing = false;
  
  SyncService._internal();
  
  Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      await _syncTransactions();
      await _syncAccounts();
      await _syncCategories();
      await _markSynced();
    } catch (e) {
      // TODO: 使用日志框架
    } finally {
      _isSyncing = false;
    }
  }
  
  Future<void> _syncTransactions() async {
    try {
      final data = await _api.getTransactions(page: 1, pageSize: 100);
      final items = data['items'] as List;
      
      for (final item in items) {
        await _db.insertTransaction(Map<String, dynamic>.from(item));
      }
    } catch (e) {
      // TODO: 使用日志框架
    }
  }
  
  Future<void> _syncAccounts() async {
    try {
      final data = await _api.getAccounts();
      for (final item in data) {
        await _db.insertAccount(Map<String, dynamic>.from(item));
      }
    } catch (e) {
      // TODO: 使用日志框架
    }
  }
  
  Future<void> _syncCategories() async {
    try {
      final data = await _api.getCategories();
      for (final item in data) {
        await _db.insertCategory(Map<String, dynamic>.from(item));
      }
    } catch (e) {
      // TODO: 使用日志框架
    }
  }
  
  Future<void> _markSynced() async {
    final logs = await _db.getUnsyncedLogs();
    for (final log in logs) {
      await _db.markSynced(log['id'] as int);
    }
  }
  
  Future<void> pushLocalChanges() async {
    final logs = await _db.getUnsyncedLogs();
    
    for (final log in logs) {
      try {
        // TODO: 根据表名和操作类型推送到服务器
        await _db.markSynced(log['id'] as int);
      } catch (e) {
        // TODO: 使用日志框架
      }
    }
  }
  
  bool get isSyncing => _isSyncing;
}
