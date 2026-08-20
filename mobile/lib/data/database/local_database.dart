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
      version: 5,
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

    // 家庭表
    await db.execute('''
      CREATE TABLE families (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        invite_code TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 家庭成员表
    await db.execute('''
      CREATE TABLE family_members (
        id INTEGER PRIMARY KEY,
        nickname TEXT,
        phone TEXT,
        avatar_url TEXT,
        role TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 借贷表
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        type TEXT,
        counterparty TEXT,
        amount INTEGER,
        currency TEXT DEFAULT 'CNY',
        payment_account_id INTEGER,
        debt_date TEXT,
        due_date TEXT,
        status TEXT DEFAULT 'pending',
        repaid_amount INTEGER DEFAULT 0,
        description TEXT,
        created_by INTEGER,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 借贷还款表
    await db.execute('''
      CREATE TABLE debt_repayments (
        id INTEGER PRIMARY KEY,
        debt_id INTEGER,
        amount INTEGER,
        repayment_date TEXT,
        payment_account_id INTEGER,
        description TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 储蓄目标表
    await db.execute('''
      CREATE TABLE savings_goals (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        name TEXT,
        icon TEXT,
        color TEXT,
        target_amount INTEGER,
        current_amount INTEGER DEFAULT 0,
        account_id INTEGER,
        start_date TEXT,
        target_date TEXT,
        status TEXT DEFAULT 'active',
        progress REAL DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 周期交易表
    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        book_id INTEGER,
        type TEXT,
        amount INTEGER,
        currency TEXT DEFAULT 'CNY',
        category_id INTEGER,
        sub_category_id INTEGER,
        payment_account_id INTEGER,
        merchant_name TEXT,
        description TEXT,
        frequency TEXT,
        day_of_month INTEGER,
        day_of_week INTEGER,
        interval_value INTEGER DEFAULT 1,
        start_date TEXT,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        next_run_date TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 报销表
    await db.execute('''
      CREATE TABLE reimbursements (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        title TEXT,
        total_amount INTEGER,
        status TEXT DEFAULT 'draft',
        description TEXT,
        submitted_at TEXT,
        approved_at TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 规则表
    await db.execute('''
      CREATE TABLE rules (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        name TEXT,
        conditions TEXT,
        actions TEXT,
        priority INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 信用账单表
    await db.execute('''
      CREATE TABLE credit_bills (
        id INTEGER PRIMARY KEY,
        family_id INTEGER,
        account_id INTEGER,
        account_name TEXT,
        year INTEGER,
        month INTEGER,
        total_amount INTEGER,
        paid_amount INTEGER,
        due_date TEXT,
        status TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 通知表
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY,
        title TEXT,
        content TEXT,
        type TEXT,
        is_read INTEGER DEFAULT 0,
        related_type TEXT,
        related_id INTEGER,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0
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
    try {
      final db = await database;
      await db.delete('accounts');
      for (final acc in accounts) {
        final map = Map<String, dynamic>.from(acc as Map);
        final cached = {
          'id': map['id'],
          'family_id': map['family_id'] ?? 0,
          'user_id': map['user_id'] ?? 0,
          'name': map['name'],
          'type_code': map['type_code'],
          'icon': map['icon'],
          'color': map['color'],
          'bank_name': map['bank_name'],
          'card_tail': map['card_tail'],
          'card_type': map['card_type'],
          'initial_balance': map['initial_balance'] ?? 0,
          'credit_limit': map['credit_limit'],
          'parent_id': map['parent_id'],
          'channel_id': map['channel_id'],
        'is_active': (map['is_active'] == true || map['is_active'] == 1) ? 1 : 0,
        'balance': map['balance'],
        'is_synced': 1,
      };
      await db.insert('accounts', cached);
    }
    } catch (e) {
      print('CACHE_ACCOUNTS_ERROR: $e');
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
    try {
      final db = await database;
      await db.delete('categories');
      for (final cat in categories) {
        final map = Map<String, dynamic>.from(cat as Map);
        final cached = {
          'id': map['id'],
          'family_id': map['family_id'],
          'parent_id': map['parent_id'],
          'level': map['level'] ?? 1,
          'name': map['name'],
          'icon': map['icon'],
          'color': map['color'],
          'type': map['type'] ?? 'expense',
          'sort_order': map['sort_order'] ?? 0,
          'is_active': (map['is_active'] == true || map['is_active'] == 1) ? 1 : 0,
          'is_synced': 1,
        };
        await db.insert('categories', cached);
      }
    } catch (e) {
      print('CACHE_CATEGORIES_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedCategories() async {
    final db = await database;
    return await db.query('categories', where: 'is_active = 1');
  }

  // 预算操作
  Future<void> cacheBudgets(List<dynamic> budgets) async {
    try {
      final db = await database;
      await db.delete('budgets');
      for (final budget in budgets) {
        final map = Map<String, dynamic>.from(budget as Map);
        final cached = {
          'id': map['id'],
          'family_id': map['family_id'],
          'book_id': map['book_id'],
          'category_id': map['category_id'],
          'amount': map['amount'],
          'currency': map['currency'] ?? 'CNY',
          'period': map['period'],
          'year': map['year'],
          'month': map['month'],
          'week_start_date': map['week_start_date']?.toString(),
          'rollover': (map['rollover'] == true || map['rollover'] == 1) ? 1 : 0,
          'rollover_amount': map['rollover_amount'] ?? 0,
          'alert_threshold': (map['alert_threshold'] ?? 0.8).toDouble(),
          'is_synced': 1,
        };
        await db.insert('budgets', cached);
      }
    } catch (e) {
      print('CACHE_BUDGETS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedBudgets() async {
    final db = await database;
    return await db.query('budgets');
  }

  // 家庭操作
  Future<void> cacheFamily(Map<String, dynamic> family) async {
    try {
      final db = await database;
      await db.delete('families');
      await db.insert('families', {
        'id': family['id'],
        'name': family['name'] ?? '我的家庭',
        'invite_code': family['invite_code'],
        'created_at': family['created_at']?.toString(),
        'is_synced': 1,
      });
    } catch (e) {
      print('CACHE_FAMILY_ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedFamily() async {
    final db = await database;
    final results = await db.query('families', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> cacheFamilyMembers(List<dynamic> members) async {
    try {
      final db = await database;
      await db.delete('family_members');
      for (final member in members) {
        final map = Map<String, dynamic>.from(member as Map);
        await db.insert('family_members', {
          'id': map['id'],
          'nickname': map['nickname'],
          'phone': map['phone'],
          'avatar_url': map['avatar_url'],
          'role': map['role'],
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_MEMBERS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedFamilyMembers() async {
    final db = await database;
    return await db.query('family_members');
  }

  // 借贷操作
  Future<void> cacheDebts(List<dynamic> debts) async {
    try {
      final db = await database;
      await db.delete('debts');
      for (final debt in debts) {
        final map = Map<String, dynamic>.from(debt as Map);
        await db.insert('debts', {
          'id': map['id'],
          'family_id': map['family_id'],
          'type': map['type'],
          'counterparty': map['counterparty'],
          'amount': map['amount'],
          'currency': map['currency'] ?? 'CNY',
          'payment_account_id': map['payment_account_id'],
          'debt_date': map['debt_date']?.toString(),
          'due_date': map['due_date']?.toString(),
          'status': map['status'] ?? 'pending',
          'repaid_amount': map['repaid_amount'] ?? 0,
          'description': map['description'],
          'created_by': map['created_by'],
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_DEBTS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedDebts() async {
    final db = await database;
    return await db.query('debts', orderBy: 'debt_date DESC');
  }

  Future<void> cacheDebtRepayments(int debtId, List<dynamic> repayments) async {
    try {
      final db = await database;
      await db.delete('debt_repayments', where: 'debt_id = ?', whereArgs: [debtId]);
      for (final r in repayments) {
        final map = Map<String, dynamic>.from(r as Map);
        await db.insert('debt_repayments', {
          'id': map['id'],
          'debt_id': map['debt_id'] ?? debtId,
          'amount': map['amount'],
          'repayment_date': map['repayment_date']?.toString(),
          'payment_account_id': map['payment_account_id'],
          'description': map['description'],
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_REPAYMENTS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedDebtRepayments(int debtId) async {
    final db = await database;
    return await db.query('debt_repayments', where: 'debt_id = ?', whereArgs: [debtId], orderBy: 'repayment_date DESC');
  }

  // 储蓄目标操作
  Future<void> cacheSavingsGoals(List<dynamic> goals) async {
    try {
      final db = await database;
      await db.delete('savings_goals');
      for (final goal in goals) {
        final map = Map<String, dynamic>.from(goal as Map);
        await db.insert('savings_goals', {
          'id': map['id'],
          'family_id': map['family_id'],
          'name': map['name'],
          'icon': map['icon'],
          'color': map['color'],
          'target_amount': map['target_amount'],
          'current_amount': map['current_amount'] ?? 0,
          'account_id': map['account_id'],
          'start_date': map['start_date']?.toString(),
          'target_date': map['target_date']?.toString(),
          'status': map['status'] ?? 'active',
          'progress': (map['progress'] ?? 0).toDouble(),
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_SAVINGS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedSavingsGoals() async {
    final db = await database;
    return await db.query('savings_goals', orderBy: 'start_date DESC');
  }

  // 周期交易操作
  Future<void> cacheRecurring(List<dynamic> items) async {
    try {
      final db = await database;
      await db.delete('recurring_transactions');
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        await db.insert('recurring_transactions', {
          'id': map['id'],
          'family_id': map['family_id'],
          'book_id': map['book_id'],
          'type': map['type'],
          'amount': map['amount'],
          'currency': map['currency'] ?? 'CNY',
          'category_id': map['category_id'],
          'sub_category_id': map['sub_category_id'],
          'payment_account_id': map['payment_account_id'],
          'merchant_name': map['merchant_name'],
          'description': map['description'],
          'frequency': map['frequency'],
          'day_of_month': map['day_of_month'],
          'day_of_week': map['day_of_week'],
          'interval_value': map['interval_value'] ?? 1,
          'start_date': map['start_date']?.toString(),
          'end_date': map['end_date']?.toString(),
          'is_active': (map['is_active'] == true || map['is_active'] == 1) ? 1 : 0,
          'next_run_date': map['next_run_date']?.toString(),
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_RECURRING_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedRecurring() async {
    final db = await database;
    return await db.query('recurring_transactions', orderBy: 'start_date DESC');
  }

  // 报销操作
  Future<void> cacheReimbursements(List<dynamic> items) async {
    try {
      final db = await database;
      await db.delete('reimbursements');
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        await db.insert('reimbursements', {
          'id': map['id'],
          'family_id': map['family_id'],
          'title': map['title'],
          'total_amount': map['total_amount'],
          'status': map['status'] ?? 'draft',
          'description': map['description'],
          'submitted_at': map['submitted_at']?.toString(),
          'approved_at': map['approved_at']?.toString(),
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_REIMBURSEMENTS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedReimbursements() async {
    final db = await database;
    return await db.query('reimbursements', orderBy: 'id DESC');
  }

  // 规则操作
  Future<void> cacheRules(List<dynamic> items) async {
    try {
      final db = await database;
      await db.delete('rules');
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        await db.insert('rules', {
          'id': map['id'],
          'family_id': map['family_id'],
          'name': map['name'],
          'conditions': map['conditions']?.toString(),
          'actions': map['actions']?.toString(),
          'priority': map['priority'] ?? 0,
          'is_active': (map['is_active'] == true || map['is_active'] == 1) ? 1 : 0,
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_RULES_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedRules() async {
    final db = await database;
    return await db.query('rules', orderBy: 'priority DESC');
  }

  // 信用账单操作
  Future<void> cacheCreditBills(List<dynamic> bills) async {
    try {
      final db = await database;
      await db.delete('credit_bills');
      for (final bill in bills) {
        final map = Map<String, dynamic>.from(bill as Map);
        await db.insert('credit_bills', {
          'id': map['id'],
          'family_id': map['family_id'],
          'account_id': map['account_id'],
          'account_name': map['account_name'],
          'year': map['year'],
          'month': map['month'],
          'total_amount': map['total_amount'],
          'paid_amount': map['paid_amount'],
          'due_date': map['due_date']?.toString(),
          'status': map['status'],
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_CREDIT_BILLS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedCreditBills() async {
    final db = await database;
    return await db.query('credit_bills', orderBy: 'year DESC, month DESC');
  }

  // 通知操作
  Future<void> cacheNotifications(List<dynamic> items) async {
    try {
      final db = await database;
      await db.delete('notifications');
      for (final item in items) {
        final map = Map<String, dynamic>.from(item as Map);
        await db.insert('notifications', {
          'id': map['id'],
          'title': map['title'],
          'content': map['content'],
          'type': map['type'],
          'is_read': (map['is_read'] == true || map['is_read'] == 1) ? 1 : 0,
          'related_type': map['related_type'],
          'related_id': map['related_id'],
          'created_at': map['created_at']?.toString(),
          'is_synced': 1,
        });
      }
    } catch (e) {
      print('CACHE_NOTIFICATIONS_ERROR: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedNotifications() async {
    final db = await database;
    return await db.query('notifications', orderBy: 'created_at DESC');
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
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE families (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          invite_code TEXT,
          created_at TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE family_members (
          id INTEGER PRIMARY KEY,
          nickname TEXT,
          phone TEXT,
          avatar_url TEXT,
          role TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE debts (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          type TEXT,
          counterparty TEXT,
          amount INTEGER,
          currency TEXT DEFAULT 'CNY',
          payment_account_id INTEGER,
          debt_date TEXT,
          due_date TEXT,
          status TEXT DEFAULT 'pending',
          repaid_amount INTEGER DEFAULT 0,
          description TEXT,
          created_by INTEGER,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE debt_repayments (
          id INTEGER PRIMARY KEY,
          debt_id INTEGER,
          amount INTEGER,
          repayment_date TEXT,
          payment_account_id INTEGER,
          description TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE savings_goals (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          name TEXT,
          icon TEXT,
          color TEXT,
          target_amount INTEGER,
          current_amount INTEGER DEFAULT 0,
          account_id INTEGER,
          start_date TEXT,
          target_date TEXT,
          status TEXT DEFAULT 'active',
          progress REAL DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE recurring_transactions (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          book_id INTEGER,
          type TEXT,
          amount INTEGER,
          currency TEXT DEFAULT 'CNY',
          category_id INTEGER,
          sub_category_id INTEGER,
          payment_account_id INTEGER,
          merchant_name TEXT,
          description TEXT,
          frequency TEXT,
          day_of_month INTEGER,
          day_of_week INTEGER,
          interval_value INTEGER DEFAULT 1,
          start_date TEXT,
          end_date TEXT,
          is_active INTEGER DEFAULT 1,
          next_run_date TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE reimbursements (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          title TEXT,
          total_amount INTEGER,
          status TEXT DEFAULT 'draft',
          description TEXT,
          submitted_at TEXT,
          approved_at TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE rules (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          name TEXT,
          conditions TEXT,
          actions TEXT,
          priority INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE credit_bills (
          id INTEGER PRIMARY KEY,
          family_id INTEGER,
          account_id INTEGER,
          account_name TEXT,
          year INTEGER,
          month INTEGER,
          total_amount INTEGER,
          paid_amount INTEGER,
          due_date TEXT,
          status TEXT,
          is_synced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE notifications (
          id INTEGER PRIMARY KEY,
          title TEXT,
          content TEXT,
          type TEXT,
          is_read INTEGER DEFAULT 0,
          related_type TEXT,
          related_id INTEGER,
          created_at TEXT,
          is_synced INTEGER DEFAULT 0
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
