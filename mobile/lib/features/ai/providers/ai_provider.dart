import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final aiSuggestionsProvider = FutureProvider.family<List<AISuggestion>, ({String? type, String? status})>((ref, params) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getAISuggestions(type: params.type, status: params.status);
  return data.map((json) => AISuggestion.fromJson(json)).toList();
});

final aiSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getAISettings();
});

final aiProvidersListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getAIProviders();
});
