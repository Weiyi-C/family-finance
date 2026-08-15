class Transaction {
  final int id;
  final int familyId;
  final int bookId;
  final int entryId;
  final String entrySide;
  final String type;
  final int amount;
  final String currency;
  final int? categoryId;
  final int? subCategoryId;
  final int? paymentAccountId;
  final int? paymentChannelId;
  final int? platformId;
  final String? merchantName;
  final String? description;
  final DateTime transactionTime;
  final DateTime recordedAt;
  final int recordedBy;
  final int? paidBy;
  final bool isQuickEntry;
  final String completionStatus;
  final List<int>? tagIds;
  
  Transaction({
    required this.id,
    required this.familyId,
    required this.bookId,
    required this.entryId,
    required this.entrySide,
    required this.type,
    required this.amount,
    this.currency = 'CNY',
    this.categoryId,
    this.subCategoryId,
    this.paymentAccountId,
    this.paymentChannelId,
    this.platformId,
    this.merchantName,
    this.description,
    required this.transactionTime,
    required this.recordedAt,
    required this.recordedBy,
    this.paidBy,
    this.isQuickEntry = false,
    this.completionStatus = 'complete',
    this.tagIds,
  });
  
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      familyId: json['family_id'],
      bookId: json['book_id'],
      entryId: json['entry_id'],
      entrySide: json['entry_side'],
      type: json['type'],
      amount: json['amount'],
      currency: json['currency'] ?? 'CNY',
      categoryId: json['category_id'],
      subCategoryId: json['sub_category_id'],
      paymentAccountId: json['payment_account_id'],
      paymentChannelId: json['payment_channel_id'],
      platformId: json['platform_id'],
      merchantName: json['merchant_name'],
      description: json['description'],
      transactionTime: DateTime.parse(json['transaction_time']),
      recordedAt: DateTime.parse(json['recorded_at']),
      recordedBy: json['recorded_by'],
      paidBy: json['paid_by'],
      isQuickEntry: json['is_quick_entry'] ?? false,
      completionStatus: json['completion_status'] ?? 'complete',
      tagIds: json['tag_ids'] != null ? List<int>.from(json['tag_ids']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'payment_account_id': paymentAccountId,
      'payment_channel_id': paymentChannelId,
      'platform_id': platformId,
      'merchant_name': merchantName,
      'description': description,
      'transaction_time': transactionTime.toIso8601String(),
      'is_quick_entry': isQuickEntry,
      'completion_status': completionStatus,
      'tag_ids': tagIds,
    };
  }
  
  String get typeDisplay {
    switch (type) {
      case 'expense': return '支出';
      case 'income': return '收入';
      case 'transfer': return '资金转移';
      default: return type;
    }
  }
  
  double get amountYuan => amount / 100;
}

class Account {
  final int id;
  final int familyId;
  final int userId;
  final String name;
  final String typeCode;
  final String? icon;
  final String? color;
  final String? bankName;
  final String? cardTail;
  final String? cardType;
  final int initialBalance;
  final int? creditLimit;
  final int? parentId;
  final int? channelId;
  final bool isActive;
  final int? balance;
  
  Account({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.name,
    required this.typeCode,
    this.icon,
    this.color,
    this.bankName,
    this.cardTail,
    this.cardType,
    this.initialBalance = 0,
    this.creditLimit,
    this.parentId,
    this.channelId,
    this.isActive = true,
    this.balance,
  });
  
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      familyId: json['family_id'],
      userId: json['user_id'],
      name: json['name'],
      typeCode: json['type_code'],
      icon: json['icon'],
      color: json['color'],
      bankName: json['bank_name'],
      cardTail: json['card_tail'],
      cardType: json['card_type'],
      initialBalance: json['initial_balance'] ?? 0,
      creditLimit: json['credit_limit'],
      parentId: json['parent_id'],
      channelId: json['channel_id'],
      isActive: json['is_active'] ?? true,
      balance: json['balance'],
    );
  }
  
  double get balanceYuan => (balance ?? initialBalance) / 100;
}

class Category {
  final int id;
  final int? familyId;
  final int? parentId;
  final int level;
  final String name;
  final String? icon;
  final String? color;
  final String type;
  final int sortOrder;
  final bool isActive;
  final List<Category>? children;
  
  Category({
    required this.id,
    this.familyId,
    this.parentId,
    required this.level,
    required this.name,
    this.icon,
    this.color,
    this.type = 'expense',
    this.sortOrder = 0,
    this.isActive = true,
    this.children,
  });
  
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      familyId: json['family_id'],
      parentId: json['parent_id'],
      level: json['level'],
      name: json['name'],
      icon: json['icon'],
      color: json['color'],
      type: json['type'] ?? 'expense',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      children: json['children'] != null
          ? (json['children'] as List).map((c) => Category.fromJson(c)).toList()
          : null,
    );
  }
}

class User {
  final int id;
  final String phone;
  final String? nickname;
  final String? avatar;
  final int? familyId;
  final Map<String, dynamic>? settings;
  
  User({
    required this.id,
    required this.phone,
    this.nickname,
    this.avatar,
    this.familyId,
    this.settings,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      familyId: json['family_id'],
      settings: json['settings'],
    );
  }
}

class Budget {
  final int id;
  final int familyId;
  final int? bookId;
  final int? categoryId;
  final String period;
  final int year;
  final int month;
  final int amount;
  final String currency;
  final bool rollover;
  final int rolloverAmount;
  final double alertThreshold;
  final int? spent;
  
  Budget({
    required this.id,
    required this.familyId,
    this.bookId,
    this.categoryId,
    required this.period,
    required this.year,
    required this.month,
    required this.amount,
    this.currency = 'CNY',
    this.rollover = false,
    this.rolloverAmount = 0,
    this.alertThreshold = 0.8,
    this.spent,
  });
  
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      familyId: json['family_id'],
      bookId: json['book_id'],
      categoryId: json['category_id'],
      period: json['period'],
      year: json['year'],
      month: json['month'],
      amount: json['amount'],
      currency: json['currency'] ?? 'CNY',
      rollover: json['rollover'] ?? false,
      rolloverAmount: json['rollover_amount'] ?? 0,
      alertThreshold: (json['alert_threshold'] ?? 0.8).toDouble(),
      spent: json['spent'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'book_id': bookId,
      'category_id': categoryId,
      'period': period,
      'year': year,
      'month': month,
      'amount': amount,
      'currency': currency,
      'rollover': rollover,
      'rollover_amount': rolloverAmount,
      'alert_threshold': alertThreshold,
    };
  }
  
  double get amountYuan => amount / 100;
  double get spentYuan => (spent ?? 0) / 100;
  double get progress => spent != null ? (spent! / amount).clamp(0, 1) : 0;
}

class Tag {
  final int id;
  final int familyId;
  final String name;
  final String? color;

  Tag({
    required this.id,
    required this.familyId,
    required this.name,
    this.color,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      familyId: json['family_id'],
      name: json['name'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'name': name,
      'color': color,
    };
  }
}
