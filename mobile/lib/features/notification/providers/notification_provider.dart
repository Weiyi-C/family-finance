import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getNotifications();
    await db.cacheNotifications(data);
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedNotifications();
      return cached;
    } catch (_) {
      return [];
    }
  }
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiServiceProvider);
  try {
    return await api.getUnreadCount();
  } catch (_) {
    return 0;
  }
});
