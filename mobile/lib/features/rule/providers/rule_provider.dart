import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final rulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getRules();
    await db.cacheRules(data);
    return data.cast<Map<String, dynamic>>().toList();
  } catch (_) {
    try {
      final cached = await db.getCachedRules();
      return cached;
    } catch (_) {
      return [];
    }
  }
});
