import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/data/models/models.dart';
import 'package:family_finance_app/data/database/local_database.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  
  AuthState({this.user, this.isLoading = false, this.error});
  
  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  
  AuthNotifier(this._api) : super(AuthState()) {
    _loadToken();
  }
  
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      _api.setToken(token);
      await fetchUser();
    }
  }
  
  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('Connection reset')) {
      return '无法连接服务器，请检查网络或服务器地址设置';
    }
    if (msg.contains('timeout') || msg.contains('Timeout')) {
      return '连接超时，请检查网络';
    }
    return msg;
  }

  Future<void> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(phone, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('refresh_token', data['refresh_token']);
      _api.setToken(data['access_token']);
      await fetchUser();
      await _saveLocalUser(phone, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  Future<void> register(String phone, String password, String nickname) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.register(phone, password, nickname);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('refresh_token', data['refresh_token']);
      _api.setToken(data['access_token']);
      await fetchUser();
      await _saveLocalUser(phone, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  Future<void> _saveLocalUser(String phone, String password) async {
    try {
      final db = LocalDatabase();
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final now = DateTime.now().millisecondsSinceEpoch;

      final existing = await db.database.then(
        (d) => d.query('users_local', where: 'phone = ?', whereArgs: [phone], limit: 1),
      );

      if (existing.isEmpty) {
        await db.insertLocalUser({
          'local_id': 'server_${state.user?.id ?? 0}',
          'phone': phone,
          'nickname': state.user?.nickname ?? '用户',
          'password_hash': passwordHash,
          'registration_status': 'SYNCED',
          'server_id': '${state.user?.id ?? 0}',
          'family_id': '${state.user?.familyId ?? 0}',
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final localId = existing.first['local_id'] as String;
        await db.updateLocalUserStatus(localId, 'SYNCED',
          serverId: '${state.user?.id ?? 0}',
          familyId: '${state.user?.familyId ?? 0}',
        );
      }
    } catch (_) {}
  }
  
  Future<void> fetchUser() async {
    try {
      final data = await _api.getUserInfo();
      state = state.copyWith(
        user: User.fromJson(data),
        isLoading: false,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('403')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        _api.clearToken();
      }
      state = state.copyWith(isLoading: false);
    }
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    _api.clearToken();
    state = AuthState();
  }
  
  bool get isLoggedIn => state.user != null;
}
