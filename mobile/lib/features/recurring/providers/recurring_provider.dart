import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final recurringProvider = FutureProvider.family<List<RecurringTransaction>, String?>((ref, status) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getRecurringTransactions();
  return data.map((json) => RecurringTransaction.fromJson(json)).toList();
});
