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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

    // 预算表
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        book_id INTEGER,
        category_id INTEGER,
        amount INTEGER NOT NULL,
        currency TEXT DEFAULT 'CNY',
        period TEXT NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER,
        week_start_date TEXT,
        rollover INTEGER DEFAULT 0,
        rollover_amount INTEGER DEFAULT 0,
        alert_threshold REAL DEFAULT 0.8,
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

    // 本地用户表
    await db.execute('''
      CREATE TABLE users_local (
        local_id TEXT PRIMARY KEY,
        phone TEXT NOT NULL,
        nickname TEXT,
        password_hash TEXT NOT NULL,
        registration_status TEXT NOT NULL DEFAULT 'PENDING',
        server_id TEXT,
        family_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ID 映射表
    await db.execute('''
      CREATE TABLE id_mapping (
        local_id TEXT PRIMARY KEY,
        server_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        synced_at INTEGER NOT NULL
      )
    ''');

    // 同步队列表
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        local_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT DEFAULT 'PENDING',
        retry_count INTEGER DEFAULT 0,
        error_message TEXT,
        created_at INTEGER NOT NULL
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

  Future<void> cacheAccounts(List<dynamic> accounts) async {
    final db = await database;
    await db.delete('accounts');
    for (final acc in accounts) {
      final map = Map<String, dynamic>.from(acc as Map);
      map['is_synced'] = 1;
      await db.insert('accounts', map);
    }
  }

  Future<List<Map<String, dynamic>>> getCachedAccounts() async {
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

  Future<void> cacheCategories(List<dynamic> categories) async {
    final db = await database;
    await db.delete('categories');
    for (final cat in categories) {
      final map = Map<String, dynamic>.from(cat as Map);
      map['is_synced'] = 1;
      await db.insert('categories', map);
    }
  }

  Future<List<Map<String, dynamic>>> getCachedCategories() async {
    final db = await database;
    return await db.query('categories', where: 'is_active = 1');
  }

  // 预算操作
  Future<void> cacheBudgets(List<dynamic> budgets) async {
    final db = await database;
    await db.delete('budgets');
    for (final budget in budgets) {
      final map = Map<String, dynamic>.from(budget as Map);
      map['is_synced'] = 1;
      await db.insert('budgets', map);
    }
  }

  Future<List<Map<String, dynamic>>> getCachedBudgets() async {
    final db = await database;
    return await db.query('budgets');
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
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE users_local (
          local_id TEXT PRIMARY KEY,
          phone TEXT NOT NULL,
          nickname TEXT,
          password_hash TEXT NOT NULL,
          registration_status TEXT NOT NULL DEFAULT 'PENDING',
          server_id TEXT,
          family_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE id_mapping (
          local_id TEXT PRIMARY KEY,
          server_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          synced_at INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_type TEXT NOT NULL,
          local_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          payload TEXT NOT NULL,
          status TEXT DEFAULT 'PENDING',
          retry_count INTEGER DEFAULT 0,
          error_message TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE budgets (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          book_id INTEGER,
          category_id INTEGER,
          amount INTEGER NOT NULL,
          currency TEXT DEFAULT 'CNY',
          period TEXT NOT NULL,
          year INTEGER NOT NULL,
          month INTEGER,
          week_start_date TEXT,
          rollover INTEGER DEFAULT 0,
          rollover_amount INTEGER DEFAULT 0,
          alert_threshold REAL DEFAULT 0.8,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
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

  // 本地用户操作
  Future<int> insertLocalUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users_local', user);
  }

  Future<Map<String, dynamic>?> getLocalUser(String localId) async {
    final db = await database;
    final maps = await db.query('users_local', where: 'local_id = ?', whereArgs: [localId]);
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<Map<String, dynamic>?> getPendingLocalUser() async {
    final db = await database;
    final maps = await db.query(
      'users_local',
      where: 'registration_status = ?',
      whereArgs: ['PENDING'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<int> updateLocalUserStatus(
    String localId,
    String status, {
    String? serverId,
    String? familyId,
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'registration_status': status,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (serverId != null) data['server_id'] = serverId;
    if (familyId != null) data['family_id'] = familyId;
    return await db.update('users_local', data, where: 'local_id = ?', whereArgs: [localId]);
  }

  // ID 映射操作
  Future<int> insertIdMapping(Map<String, dynamic> mapping) async {
    final db = await database;
    return await db.insert('id_mapping', mapping);
  }

  Future<String?> getServerId(String localId, String entityType) async {
    final db = await database;
    final maps = await db.query(
      'id_mapping',
      where: 'local_id = ? AND entity_type = ?',
      whereArgs: [localId, entityType],
    );
    if (maps.isEmpty) return null;
    return maps.first['server_id'] as String?;
  }

  // 同步队列操作
  Future<int> enqueueSync(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('sync_queue', item);
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int? limit}) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<int> updateSyncStatus(
    int id,
    String status, {
    String? errorMessage,
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'status': status,
    };
    if (errorMessage != null) {
      data['error_message'] = errorMessage;
    }
    if (status == 'FAILED') {
      final item = await db.query('sync_queue', where: 'id = ?', whereArgs: [id]);
      if (item.isNotEmpty) {
        data['retry_count'] = (item.first['retry_count'] as int) + 1;
      }
    }
    return await db.update('sync_queue', data, where: 'id = ?', whereArgs: [id]);
  }
}
