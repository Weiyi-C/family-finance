import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  String? _baseUrl;
  
  ApiService._internal() {
    _dio = Dio();
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
  
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? 'http://localhost:8080';
    _dio.options.baseUrl = '$_baseUrl/api';
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }
  
  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }
  
  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }
  
  // 认证
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    return response.data;
  }
  
  Future<Map<String, dynamic>> register(String phone, String password, String nickname) async {
    final response = await _dio.post('/auth/register', data: {
      'phone': phone,
      'password': password,
      'nickname': nickname,
    });
    return response.data;
  }
  
  // 交易
  Future<Map<String, dynamic>> getTransactions({
    int? page,
    int? pageSize,
    String? type,
    int? categoryId,
    int? accountId,
    String? startDate,
    String? endDate,
    String? keyword,
  }) async {
    final params = <String, dynamic>{
      'page': page ?? 1,
      'page_size': pageSize ?? 20,
    };
    if (type != null) params['type'] = type;
    if (categoryId != null) params['category_id'] = categoryId;
    if (accountId != null) params['payment_account_id'] = accountId;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (keyword != null) params['keyword'] = keyword;
    
    final response = await _dio.get('/transactions', queryParameters: params);
    return response.data;
  }
  
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final response = await _dio.post('/transactions', data: data);
    return response.data;
  }
  
  Future<Map<String, dynamic>> updateTransaction(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/transactions/$id', data: data);
    return response.data;
  }
  
  Future<void> deleteTransaction(int id) async {
    await _dio.delete('/transactions/$id');
  }
  
  // 账户
  Future<List<dynamic>> getAccounts() async {
    final response = await _dio.get('/accounts');
    return response.data;
  }
  
  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async {
    final response = await _dio.post('/accounts', data: data);
    return response.data;
  }
  
  // 分类
  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('/categories');
    return response.data;
  }
  
  // 预算
  Future<List<dynamic>> getBudgets() async {
    final response = await _dio.get('/budgets');
    return response.data;
  }
  
  // 统计
  Future<Map<String, dynamic>> getStatsSummary({
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    
    final response = await _dio.get('/stats/summary', queryParameters: params);
    return response.data;
  }
  
  Future<Map<String, dynamic>> getStatsByCategory({
    int? year,
    int? month,
  }) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    
    final response = await _dio.get('/stats/by-category', queryParameters: params);
    return response.data;
  }
  
  // 用户
  Future<Map<String, dynamic>> getUserInfo() async {
    final response = await _dio.get('/users/me');
    return response.data;
  }
  
  // 汇率
  Future<List<dynamic>> getExchangeRates() async {
    final response = await _dio.get('/exchange-rates');
    return response.data;
  }
  
  // 信用账单
  Future<List<dynamic>> getCreditBills() async {
    final response = await _dio.get('/credit-bills');
    return response.data;
  }
  
  // 周期交易
  Future<List<dynamic>> getRecurringTransactions() async {
    final response = await _dio.get('/recurring');
    return response.data;
  }
  
  // 通知
  Future<Map<String, dynamic>> getNotifications() async {
    final response = await _dio.get('/notifications');
    return response.data;
  }
  
  Future<int> getUnreadCount() async {
    final response = await _dio.get('/notifications/unread');
    return response.data['count'] ?? 0;
  }
}
