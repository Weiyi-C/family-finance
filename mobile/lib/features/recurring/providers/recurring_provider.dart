import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final recurringProvider = FutureProvider.family<List<RecurringTransaction>, String?>((ref, status) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getRecurringTransactions();
    await db.cacheRecurring(data);
    return data.map((json) => RecurringTransaction.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedRecurring();
      return cached.map((json) => RecurringTransaction.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});
