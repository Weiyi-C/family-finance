import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final importsProvider = FutureProvider<List<ImportRecord>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getImports();
  return data.map((json) => ImportRecord.fromJson(json)).toList();
});
