import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/core/network/network_status.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final budgetsProvider = FutureProvider.family<List<Budget>, ({int? year, int? month})>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getBudgets();
    await db.cacheBudgets(data);
    return data.map((json) => Budget.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedBudgets();
      return cached.map((json) => Budget.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});

final budgetUsageProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final api = ref.read(apiServiceProvider);
  return await api.getBudgetUsage(id);
});
