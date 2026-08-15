import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final familyProvider = FutureProvider<Family>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getCurrentFamily();
  return Family.fromJson(data);
});

final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getFamilyMembers();
  return data.map((json) => FamilyMember.fromJson(json)).toList();
});
