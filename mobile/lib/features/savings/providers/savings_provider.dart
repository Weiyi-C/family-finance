import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final savingsGoalsProvider = FutureProvider.family<List<SavingsGoal>, String?>((ref, status) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getSavingsGoals(status: status);
  return data.map((json) => SavingsGoal.fromJson(json)).toList();
});
