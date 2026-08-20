import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final debtsProvider = FutureProvider.family<List<Debt>, ({String? type, String? status})>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getDebts(type: params.type, status: params.status);
    await db.cacheDebts(data);
    return data.map((json) => Debt.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedDebts();
      return cached.map((json) => Debt.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});

final debtSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    return await api.getDebtSummary();
  } catch (_) {
    return {};
  }
});

final debtRepaymentsProvider = FutureProvider.family<List<DebtRepayment>, int>((ref, debtId) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getDebtRepayments(debtId);
    await db.cacheDebtRepayments(debtId, data);
    return data.map((json) => DebtRepayment.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedDebtRepayments(debtId);
      return cached.map((json) => DebtRepayment.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});
