import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final statsByDayProvider = FutureProvider.family<List<dynamic>, ({String? start, String? end, String? type})>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  try {
    return await api.getStatsByDay(
      start: params.start,
      end: params.end,
      type: params.type,
    );
  } catch (_) {
    return [];
  }
});
