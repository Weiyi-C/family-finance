import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getNotifications();
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getUnreadCount();
});
