import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final savingsGoalsProvider = FutureProvider.family<List<SavingsGoal>, String?>((ref, status) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getSavingsGoals(status: status);
    await db.cacheSavingsGoals(data);
    return data.map((json) => SavingsGoal.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedSavingsGoals();
      return cached.map((json) => SavingsGoal.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});
