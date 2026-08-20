import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final transactionProvider = StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  return TransactionNotifier(ref.read(apiServiceProvider));
});

class TransactionState {
  final List<Transaction> transactions;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final String? keyword;
  final String? typeFilter;

  TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.keyword,
    this.typeFilter,
  });

  TransactionState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
    String? keyword,
    String? typeFilter,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      keyword: keyword ?? this.keyword,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final ApiService _api;
  final LocalDatabase _db = LocalDatabase();

  TransactionNotifier(this._api) : super(TransactionState());

  Future<void> loadTransactions({bool refresh = false, String? keyword, String? type}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(currentPage: 1, hasMore: true, keyword: keyword, typeFilter: type);
    }

    if (!state.hasMore && !refresh) return;

    state = state.copyWith(isLoading: true);

    try {
      await _loadFromServer(refresh);
    } catch (_) {
      await _loadFromLocal(refresh);
    }
  }

  Future<void> _loadFromServer(bool refresh) async {
    final data = await _api.getTransactions(
      page: state.currentPage,
      pageSize: 20,
      type: state.typeFilter,
      keyword: state.keyword,
    );

    final items = (data['items'] as List)
        .map((json) => Transaction.fromJson(json))
        .toList();

    if (refresh) {
      final cacheResult = await _cacheToLocal(data['items'] as List);
      if (!cacheResult) {
        foundation.debugPrint('⚠ 缓存失败，但继续展示API数据');
      }
    }

    final total = data['total'] as int;
    final hasMore = state.transactions.length + items.length < total;

    state = state.copyWith(
      transactions: refresh ? items : [...state.transactions, ...items],
      isLoading: false,
      hasMore: hasMore,
      currentPage: state.currentPage + 1,
    );
  }

  Future<void> _loadFromLocal(bool refresh) async {
    final localData = await _db.getTransactions(
      limit: 20,
      offset: refresh ? 0 : state.transactions.length,
      type: state.typeFilter,
    );

    final items = localData.map((json) => Transaction.fromJson(json)).toList();

    state = state.copyWith(
      transactions: refresh ? items : [...state.transactions, ...items],
      isLoading: false,
      hasMore: items.length >= 20,
      currentPage: state.currentPage + 1,
    );
  }

  Future<bool> _cacheToLocal(List<dynamic> serverItems) async {
    try {
      for (final item in serverItems) {
        final map = Map<String, dynamic>.from(item as Map);
        final cached = {
          'id': map['id'],
          'family_id': map['family_id'] ?? 0,
          'book_id': map['book_id'] ?? 0,
          'entry_id': map['entry_id'] ?? 0,
          'entry_side': map['entry_side'] ?? '',
          'type': map['type'],
          'amount': map['amount'],
          'currency': map['currency'] ?? 'CNY',
          'category_id': map['category_id'],
          'sub_category_id': map['sub_category_id'],
          'payment_account_id': map['payment_account_id'],
          'payment_channel_id': map['payment_channel_id'],
          'platform_id': map['platform_id'],
          'merchant_name': map['merchant_name'],
          'description': map['description'],
          'transaction_time': map['transaction_time'],
          'recorded_at': map['recorded_at'] ?? map['transaction_time'],
          'recorded_by': map['recorded_by'] ?? 0,
          'paid_by': map['paid_by'],
          'is_quick_entry': (map['is_quick_entry'] == true || map['is_quick_entry'] == 1) ? 1 : 0,
          'completion_status': map['completion_status'] ?? 'complete',
          'is_synced': 1,
        'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _db.insertTransaction(cached);
    }
    return true;
    } catch (e) {
      foundation.debugPrint('⚠ 缓存到本地失败: $e');
      return false;
    }
  }

  bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('timeout') ||
        msg.contains('Timeout');
  }

  Future<void> createTransaction(Map<String, dynamic> data) async {
    try {
      data['is_synced'] = 0;
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();
      data['family_id'] = data['family_id'] ?? 0;
      data['book_id'] = data['book_id'] ?? 0;
      data['entry_id'] = data['entry_id'] ?? 0;
      data['entry_side'] = data['entry_side'] ?? '';
      data['recorded_by'] = data['recorded_by'] ?? 0;
      data['recorded_at'] = data['recorded_at'] ?? data['transaction_time'] ?? DateTime.now().toIso8601String();
      data['currency'] = data['currency'] ?? 'CNY';
      data['completion_status'] = data['completion_status'] ?? 'complete';
      await _db.insertTransaction(data);
      await _db.addSyncLog('transactions', data['id'] ?? 0, 'create', data.toString());

      try {
        await _api.createTransaction(data);
      } catch (_) {}

      await loadTransactions(refresh: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _db.deleteTransaction(id);
      await _db.addSyncLog('transactions', id, 'delete', null);

      try {
        await _api.deleteTransaction(id);
      } catch (_) {}

      state = state.copyWith(
        transactions: state.transactions.where((t) => t.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getAccounts();
    final accounts = data.map((json) => Account.fromJson(json)).toList();
    await db.cacheAccounts(data);
    return accounts;
  } catch (_) {
    try {
      final cached = await db.getCachedAccounts();
      return cached.map((json) => Account.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getCategories();
    final cats = data.map((json) => Category.fromJson(json)).toList();
    await db.cacheCategories(data);
    return cats;
  } catch (_) {
    try {
      final cached = await db.getCachedCategories();
      return cached.map((json) => Category.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});

final statsSummaryProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final api = ref.read(apiServiceProvider);
  return await api.getStatsSummary(year: date.year, month: date.month);
});

final statsByCategoryProvider = FutureProvider.family<List<dynamic>, DateTime>((ref, date) async {
  final api = ref.read(apiServiceProvider);
  return await api.getStatsByCategory(year: date.year, month: date.month);
});
