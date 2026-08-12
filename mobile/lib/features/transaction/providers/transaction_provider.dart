import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/data/models/models.dart';
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
  
  TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });
  
  TransactionState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  final ApiService _api;
  
  TransactionNotifier(this._api) : super(TransactionState());
  
  Future<void> loadTransactions({bool refresh = false}) async {
    if (state.isLoading) return;
    
    if (refresh) {
      state = state.copyWith(currentPage: 1, hasMore: true);
    }
    
    if (!state.hasMore && !refresh) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final data = await _api.getTransactions(
        page: state.currentPage,
        pageSize: 20,
      );
      
      final items = (data['items'] as List)
          .map((json) => Transaction.fromJson(json))
          .toList();
      
      final total = data['total'] as int;
      final hasMore = state.transactions.length + items.length < total;
      
      state = state.copyWith(
        transactions: refresh ? items : [...state.transactions, ...items],
        isLoading: false,
        hasMore: hasMore,
        currentPage: state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> createTransaction(Map<String, dynamic> data) async {
    try {
      await _api.createTransaction(data);
      await loadTransactions(refresh: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
  
  Future<void> deleteTransaction(int id) async {
    try {
      await _api.deleteTransaction(id);
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
  final data = await api.getAccounts();
  return data.map((json) => Account.fromJson(json)).toList();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getCategories();
  return data.map((json) => Category.fromJson(json)).toList();
});

final statsSummaryProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final api = ref.read(apiServiceProvider);
  return await api.getStatsSummary(year: date.year, month: date.month);
});

final statsByCategoryProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final api = ref.read(apiServiceProvider);
  return await api.getStatsByCategory(year: date.year, month: date.month);
});
