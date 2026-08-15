import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final debtsProvider = FutureProvider.family<List<Debt>, ({String? type, String? status})>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getDebts(type: params.type, status: params.status);
  return data.map((json) => Debt.fromJson(json)).toList();
});

final debtSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getDebtSummary();
});

final debtRepaymentsProvider = FutureProvider.family<List<DebtRepayment>, int>((ref, debtId) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getDebtRepayments(debtId);
  return data.map((json) => DebtRepayment.fromJson(json)).toList();
});
