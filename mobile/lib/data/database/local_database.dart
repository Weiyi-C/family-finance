import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_lib;

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  
  Database? _database;
  
  LocalDatabase._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbPath2 = path_lib.join(dbPath, 'family_finance.db');
    
    return await openDatabase(
      dbPath2,
      version: 1,
      onCreate: _onCreate,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // 交易表
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY,
        family_id INTEGER NOT NULL,
        book_id INTEGER NOT NULL,
        entry_id INTEGER NOT NULL,
        entry_side TEXT NOT NULL,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT DEFAULT 'CNY',
        category_id INTEGER,
        sub_category_id INTEGER,
        payment_account_id INTEGER,
        payment_channel_id INTEGER,
        platform_id INTEGER,
        merchant_name TEXT,
        description TEXT,
        transaction_time TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        recorded_by INTEGER NOT NULL,
        paid_by INTEGER,
        is_quick_entry INTEGER DEFAULT 0,
        completion_status TEXT DEFAULT 'complete',
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // 账户表
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY,
        family_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type_code TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        bank_name TEXT,
        card_tail TEXT,
        card_type TEXT,
        initial_balance INTEGER DEFAULT 0,
        credit_limit INTEGER,
        parent_id INTEGER,
        channel_id INTEGER,
        is_active INTEGER DEFAULT 1,
        balance INTEGER,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // 分类表
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        parent_id INTEGER,
        level INTEGER NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        type TEXT DEFAULT 'expense',
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    // 同步日志表
    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    
    // 用户设置表
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }
  
  // 交易操作
  Future<int> insertTransaction(Map<String, dynamic> txn) async {
    final db = await database;
    return await db.insert('transactions', txn);
  }
  
  Future<List<Map<String, dynamic>>> getTransactions({
    int? limit,
    int? offset,
    String? type,
    int? categoryId,
  }) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> whereArgs = [];
    
    if (type != null) {
      where += ' AND type = ?';
      whereArgs.add(type);
    }
    if (categoryId != null) {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }
    
    return await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'transaction_time DESC',
      limit: limit,
      offset: offset,
    );
  }
  
  Future<int> updateTransaction(int id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('transactions', data, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
  
  // 账户操作
  Future<int> insertAccount(Map<String, dynamic> account) async {
    final db = await database;
    return await db.insert('accounts', account);
  }
  
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return await db.query('accounts', where: 'is_active = 1');
  }
  
  // 分类操作
  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return await db.insert('categories', category);
  }
  
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', where: 'is_active = 1');
  }
  
  // 设置操作
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }
  
  // 同步日志
  Future<void> addSyncLog(String table, int recordId, String action, String? data) async {
    final db = await database;
    await db.insert('sync_log', {
      'table_name': table,
      'record_id': recordId,
      'action': action,
      'data': data,
      'is_synced': 0,
    });
  }
  
  Future<List<Map<String, dynamic>>> getUnsyncedLogs() async {
    final db = await database;
    return await db.query('sync_log', where: 'is_synced = 0', orderBy: 'created_at ASC');
  }
  
  Future<void> markSynced(int logId) async {
    final db = await database;
    await db.update('sync_log', {'is_synced': 1}, where: 'id = ?', whereArgs: [logId]);
  }
}
