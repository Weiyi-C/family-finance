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
      entryId: json['entry_id'] ?? 0,
      entrySide: json['entry_side'] ?? '',
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
      recordedAt: json['recorded_at'] != null ? DateTime.parse(json['recorded_at']) : DateTime.parse(json['transaction_time']),
      recordedBy: json['recorded_by'],
      paidBy: json['paid_by'],
      isQuickEntry: (json['is_quick_entry'] == true || json['is_quick_entry'] == 1),
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
      familyId: json['family_id'] ?? 0,
      parentId: json['parent_id'],
      level: json['level'] ?? 1,
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
  final int? month;
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
    this.month,
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
      month: json['month'] ?? 0,
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

class CreditBill {
  final int id;
  final int familyId;
  final int accountId;
  final String? accountName;
  final int year;
  final int month;
  final int totalAmount;
  final int paidAmount;
  final DateTime? dueDate;
  final String status;

  CreditBill({
    required this.id,
    required this.familyId,
    required this.accountId,
    this.accountName,
    required this.year,
    required this.month,
    required this.totalAmount,
    required this.paidAmount,
    this.dueDate,
    required this.status,
  });

  factory CreditBill.fromJson(Map<String, dynamic> json) {
    return CreditBill(
      id: json['id'],
      familyId: json['family_id'],
      accountId: json['account_id'],
      accountName: json['account_name'],
      year: json['year'],
      month: json['month'],
      totalAmount: json['total_amount'],
      paidAmount: json['paid_amount'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      status: json['status'],
    );
  }

  double get totalAmountYuan => totalAmount / 100;
  double get paidAmountYuan => paidAmount / 100;
  double get remainingYuan => (totalAmount - paidAmount) / 100;
}

class Debt {
  final int id;
  final int familyId;
  final String type;
  final String personName;
  final int amount;
  final String? description;
  final DateTime? dueDate;
  final String status;
  final int repaidAmount;

  Debt({
    required this.id,
    required this.familyId,
    required this.type,
    required this.personName,
    required this.amount,
    this.description,
    this.dueDate,
    required this.status,
    required this.repaidAmount,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'],
      familyId: json['family_id'],
      type: json['type'],
      personName: json['counterparty'] ?? json['person_name'] ?? '',
      amount: json['amount'],
      description: json['description'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      status: json['status'],
      repaidAmount: json['repaid_amount'],
    );
  }

  double get amountYuan => amount / 100;
  double get repaidYuan => repaidAmount / 100;
  double get remainingYuan => (amount - repaidAmount) / 100;
}

class DebtRepayment {
  final int id;
  final int debtId;
  final int amount;
  final DateTime repayDate;
  final String? description;

  DebtRepayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.repayDate,
    this.description,
  });

  factory DebtRepayment.fromJson(Map<String, dynamic> json) {
    return DebtRepayment(
      id: json['id'],
      debtId: json['debt_id'],
      amount: json['amount'],
      repayDate: DateTime.parse(json['repay_date']),
      description: json['description'],
    );
  }

  double get amountYuan => amount / 100;
}

class SavingsGoal {
  final int id;
  final int familyId;
  final String name;
  final int targetAmount;
  final int currentAmount;
  final DateTime? deadline;
  final String status;
  final String? icon;
  final String? color;

  SavingsGoal({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.status,
    this.icon,
    this.color,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'],
      familyId: json['family_id'],
      name: json['name'],
      targetAmount: json['target_amount'],
      currentAmount: json['current_amount'],
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      status: json['status'],
      icon: json['icon'],
      color: json['color'],
    );
  }

  double get targetAmountYuan => targetAmount / 100;
  double get currentAmountYuan => currentAmount / 100;
  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0, 1) : 0;
}

class RecurringTransaction {
  final int id;
  final int familyId;
  final String type;
  final int amount;
  final int? categoryId;
  final int? accountId;
  final String? description;
  final String frequency;
  final int? dayOfMonth;
  final bool isActive;
  final DateTime? nextRunDate;

  RecurringTransaction({
    required this.id,
    required this.familyId,
    required this.type,
    required this.amount,
    this.categoryId,
    this.accountId,
    this.description,
    required this.frequency,
    this.dayOfMonth,
    this.isActive = true,
    this.nextRunDate,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'],
      familyId: json['family_id'],
      type: json['type'],
      amount: json['amount'],
      categoryId: json['category_id'],
      accountId: json['account_id'],
      description: json['description'],
      frequency: json['frequency'],
      dayOfMonth: json['day_of_month'],
      isActive: json['is_active'] ?? true,
      nextRunDate: json['next_run_date'] != null ? DateTime.parse(json['next_run_date']) : null,
    );
  }

  double get amountYuan => amount / 100;
}

class Reimbursement {
  final int id;
  final int familyId;
  final String title;
  final int totalAmount;
  final String status;
  final DateTime? submitDate;
  final List<ReimbursementItem>? items;

  Reimbursement({
    required this.id,
    required this.familyId,
    required this.title,
    required this.totalAmount,
    required this.status,
    this.submitDate,
    this.items,
  });

  factory Reimbursement.fromJson(Map<String, dynamic> json) {
    return Reimbursement(
      id: json['id'],
      familyId: json['family_id'],
      title: json['title'],
      totalAmount: json['total_amount'],
      status: json['status'],
      submitDate: json['submit_date'] != null ? DateTime.parse(json['submit_date']) : null,
      items: json['items'] != null
          ? (json['items'] as List).map((i) => ReimbursementItem.fromJson(i)).toList()
          : null,
    );
  }

  double get totalAmountYuan => totalAmount / 100;
}

class ReimbursementItem {
  final int id;
  final int reimbursementId;
  final String description;
  final int amount;
  final DateTime? date;

  ReimbursementItem({
    required this.id,
    required this.reimbursementId,
    required this.description,
    required this.amount,
    this.date,
  });

  factory ReimbursementItem.fromJson(Map<String, dynamic> json) {
    return ReimbursementItem(
      id: json['id'],
      reimbursementId: json['reimbursement_id'],
      description: json['description'],
      amount: json['amount'],
      date: json['date'] != null ? DateTime.parse(json['date']) : null,
    );
  }

  double get amountYuan => amount / 100;
}

class ImportRecord {
  final int id;
  final String filename;
  final String source;
  final String status;
  final int itemCount;
  final DateTime createdAt;

  ImportRecord({
    required this.id,
    required this.filename,
    required this.source,
    required this.status,
    required this.itemCount,
    required this.createdAt,
  });

  factory ImportRecord.fromJson(Map<String, dynamic> json) {
    return ImportRecord(
      id: json['id'],
      filename: json['filename'],
      source: json['source'],
      status: json['status'],
      itemCount: json['item_count'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AISuggestion {
  final int id;
  final int familyId;
  final String type;
  final String status;
  final List<int>? transactionIds;
  final Map<String, dynamic>? suggestion;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  AISuggestion({
    required this.id,
    required this.familyId,
    required this.type,
    required this.status,
    this.transactionIds,
    this.suggestion,
    this.reason,
    this.createdAt,
    this.resolvedAt,
  });

  factory AISuggestion.fromJson(Map<String, dynamic> json) {
    return AISuggestion(
      id: json['id'],
      familyId: json['family_id'],
      type: json['type'],
      status: json['status'],
      transactionIds: json['transaction_ids'] != null ? List<int>.from(json['transaction_ids']) : null,
      suggestion: json['suggestion'],
      reason: json['reason'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
    );
  }
}

class Family {
  final int id;
  final String name;
  final String? inviteCode;
  final int? createdBy;
  final DateTime? createdAt;

  Family({
    required this.id,
    required this.name,
    this.inviteCode,
    this.createdBy,
    this.createdAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'],
      name: json['name'],
      inviteCode: json['invite_code'],
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class FamilyMember {
  final int id;
  final String nickname;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isActive;

  FamilyMember({
    required this.id,
    required this.nickname,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.isActive = true,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'],
      nickname: json['nickname'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      role: json['role'] ?? 'member',
      isActive: json['is_active'] ?? true,
    );
  }
}
