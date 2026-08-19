import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/data/database/local_database.dart';
import 'package:family_finance_app/core/network/network_status.dart';
import 'package:family_finance_app/features/auth/providers/auth_provider.dart';

enum OfflineAuthStatus {
  idle,
  loading,
  offlineSuccess,
  onlineSuccess,
  error,
  conflict,
}

class OfflineAuthState {
  final OfflineAuthStatus status;
  final String? error;
  final String? conflictType;
  final List<String>? suggestions;

  OfflineAuthState({
    this.status = OfflineAuthStatus.idle,
    this.error,
    this.conflictType,
    this.suggestions,
  });

  OfflineAuthState copyWith({
    OfflineAuthStatus? status,
    String? error,
    String? conflictType,
    List<String>? suggestions,
  }) {
    return OfflineAuthState(
      status: status ?? this.status,
      error: error,
      conflictType: conflictType,
      suggestions: suggestions,
    );
  }
}

final offlineAuthProvider =
    StateNotifierProvider<OfflineAuthNotifier, OfflineAuthState>((ref) {
  return OfflineAuthNotifier(
    ref.read(apiServiceProvider),
    LocalDatabase(),
    ref,
  );
});

class OfflineAuthNotifier extends StateNotifier<OfflineAuthState> {
  final ApiService _api;
  final LocalDatabase _db;
  final Ref _ref;

  OfflineAuthNotifier(this._api, this._db, this._ref)
      : super(OfflineAuthState());

  Future<void> login(String phone, String password) async {
    state = OfflineAuthState(status: OfflineAuthStatus.loading);

    final networkStatus = _ref.read(networkStatusProvider);
    if (networkStatus == NetworkStatus.online) {
      await _loginOnline(phone, password);
    } else {
      await _loginOffline(phone, password);
    }
  }

  Future<void> _loginOnline(String phone, String password) async {
    try {
      final data = await _api.login(phone, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('refresh_token', data['refresh_token']);
      _api.setToken(data['access_token']);

      state = OfflineAuthState(status: OfflineAuthStatus.onlineSuccess);
    } catch (e) {
      final msg = e.toString();
      if (_isNetworkError(msg)) {
        await _loginOffline(phone, password);
      } else {
        state = OfflineAuthState(
          status: OfflineAuthStatus.error,
          error: msg.contains('401') ? '手机号或密码错误' : '登录失败: $msg',
        );
      }
    }
  }

  Future<void> _loginOffline(String phone, String password) async {
    try {
      final passwordHash = sha256.convert(utf8.encode(password)).toString();

      final db = await _db.database;
      final results = await db.query(
        'users_local',
        where: 'phone = ?',
        whereArgs: [phone],
        limit: 1,
      );

      if (results.isEmpty) {
        state = OfflineAuthState(
          status: OfflineAuthStatus.error,
          error: '离线模式下未找到该账户，请联网后登录',
        );
        return;
      }

      final user = results.first;
      if (user['password_hash'] != passwordHash) {
        state = OfflineAuthState(
          status: OfflineAuthStatus.error,
          error: '手机号或密码错误',
        );
        return;
      }

      final localId = user['local_id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_user_id', localId);
      await prefs.setBool('is_offline_user', true);
      await prefs.setString('offline_nickname', (user['nickname'] as String?) ?? '用户');
      await prefs.setString('offline_phone', phone);

      state = OfflineAuthState(status: OfflineAuthStatus.offlineSuccess);
    } catch (e) {
      state = OfflineAuthState(
        status: OfflineAuthStatus.error,
        error: '离线登录失败: $e',
      );
    }
  }

  bool _isNetworkError(String msg) {
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('timeout') ||
        msg.contains('Timeout');
  }

  Future<void> register(String phone, String password, String nickname) async {
    state = OfflineAuthState(status: OfflineAuthStatus.loading);

    final networkStatus = _ref.read(networkStatusProvider);
    if (networkStatus == NetworkStatus.online) {
      await _registerOnline(phone, password, nickname);
    } else {
      await _registerOffline(phone, password, nickname);
    }
  }

  Future<void> _registerOnline(
      String phone, String password, String nickname) async {
    try {
      final data = await _api.register(phone, password, nickname);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('refresh_token', data['refresh_token']);
      _api.setToken(data['access_token']);

      state = OfflineAuthState(status: OfflineAuthStatus.onlineSuccess);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('PHONE_TAKEN')) {
        state = OfflineAuthState(
          status: OfflineAuthStatus.conflict,
          error: '手机号已注册',
          conflictType: 'PHONE_TAKEN',
          suggestions: ['直接登录', '使用其他手机号'],
        );
      } else {
        await _registerOffline(phone, password, nickname);
      }
    }
  }

  Future<void> _registerOffline(
      String phone, String password, String nickname) async {
    try {
      final localId = const Uuid().v4();
      final passwordHash = sha256.convert(utf8.encode(password)).toString();
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.insertLocalUser({
        'local_id': localId,
        'phone': phone,
        'nickname': nickname,
        'password_hash': passwordHash,
        'registration_status': 'PENDING',
        'created_at': now,
        'updated_at': now,
      });

      await _db.enqueueSync({
        'entity_type': 'user',
        'local_id': localId,
        'operation': 'REGISTER',
        'payload': jsonEncode({
          'phone': phone,
          'nickname': nickname,
          'password_hash': passwordHash,
        }),
        'status': 'PENDING',
        'retry_count': 0,
        'created_at': now,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_user_id', localId);
      await prefs.setBool('is_offline_user', true);

      state = OfflineAuthState(status: OfflineAuthStatus.offlineSuccess);
    } catch (e) {
      state = OfflineAuthState(
        status: OfflineAuthStatus.error,
        error: '离线注册失败: ${e.toString()}',
      );
    }
  }

  Future<void> syncRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString('local_user_id');
    if (localId == null) return;

    final localUser = await _db.getLocalUser(localId);
    if (localUser == null) return;
    if (localUser['registration_status'] == 'SYNCED') return;

    try {
      final data = await _api.syncRegister(
        clientId: localId,
        phone: localUser['phone'] as String,
        passwordHash: localUser['password_hash'] as String,
        nickname: (localUser['nickname'] as String?) ?? '',
      );

      final serverId = data['user_id']?.toString();
      final familyId = data['family_id']?.toString();

      await _db.updateLocalUserStatus(
        localId,
        'SYNCED',
        serverId: serverId,
        familyId: familyId,
      );

      if (serverId != null) {
        await _db.insertIdMapping({
          'local_id': localId,
          'server_id': serverId,
          'entity_type': 'user',
          'synced_at': DateTime.now().millisecondsSinceEpoch,
        });
      }

      if (data['access_token'] != null) {
        await prefs.setString('access_token', data['access_token']);
        _api.setToken(data['access_token']);
      }
      if (data['refresh_token'] != null) {
        await prefs.setString('refresh_token', data['refresh_token']);
      }

      await prefs.remove('is_offline_user');
    } catch (e) {
      state = OfflineAuthState(
        status: OfflineAuthStatus.error,
        error: '同步注册失败: ${e.toString()}',
      );
    }
  }

  void clearError() {
    state = OfflineAuthState(status: OfflineAuthStatus.idle);
  }
}
