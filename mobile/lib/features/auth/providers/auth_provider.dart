import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_finance_app/data/services/api_service.dart';
import 'package:family_finance_app/data/models/models.dart';

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
  
  Future<void> login(String phone, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(phone, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', data['access_token']);
      await prefs.setString('refresh_token', data['refresh_token']);
      _api.setToken(data['access_token']);
      await fetchUser();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> fetchUser() async {
    try {
      final data = await _api.getUserInfo();
      state = state.copyWith(
        user: User.fromJson(data),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
