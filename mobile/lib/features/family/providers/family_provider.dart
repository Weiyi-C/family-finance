import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/core/network/network_status.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

final familyProvider = FutureProvider<Family>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getCurrentFamily();
    await db.cacheFamily(data);
    return Family.fromJson(data);
  } catch (_) {
    try {
      final cached = await db.getCachedFamily();
      if (cached != null) return Family.fromJson(cached);
    } catch (_) {}
    return Family(id: 0, name: '我的家庭');
  }
});

final familyMembersProvider = FutureProvider<List<FamilyMember>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final db = LocalDatabase();
  try {
    final data = await api.getFamilyMembers();
    await db.cacheFamilyMembers(data);
    return data.map((json) => FamilyMember.fromJson(json)).toList();
  } catch (_) {
    try {
      final cached = await db.getCachedFamilyMembers();
      return cached.map((json) => FamilyMember.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }
});
