import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final reimbursementsProvider = FutureProvider.family<List<Reimbursement>, String?>((ref, status) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getReimbursements(status: status);
    await db.cacheReimbursements(data);
    return data.map((json) => Reimbursement.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedReimbursements();
      return cached.map((json) => Reimbursement.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});
