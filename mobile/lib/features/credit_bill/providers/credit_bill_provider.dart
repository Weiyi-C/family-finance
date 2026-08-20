import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final creditBillsProvider = FutureProvider<List<CreditBill>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getCreditBills();
    await db.cacheCreditBills(data);
    return data.map((json) => CreditBill.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedCreditBills();
      return cached.map((json) => CreditBill.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});

final creditBillSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    return await api.getCreditBillSummary();
  } catch (_) {
    return {};
  }
});
