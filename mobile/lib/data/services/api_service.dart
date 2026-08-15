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
  
  Future<Map<String, dynamic>> syncRegister({
    required String clientId,
    required String phone,
    required String passwordHash,
    required String nickname,
  }) async {
    final response = await _dio.post('/sync/register', data: {
      'client_id': clientId,
      'phone': phone,
      'password_hash': passwordHash,
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
  
  Future<Map<String, dynamic>> getAccountById(int id) async {
    final response = await _dio.get('/accounts/$id');
    return response.data;
  }
  
  Future<Map<String, dynamic>> updateAccount(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/accounts/$id', data: data);
    return response.data;
  }
  
  Future<void> deleteAccount(int id) async {
    await _dio.delete('/accounts/$id');
  }
  
  // 分类
  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('/categories');
    return response.data;
  }
  
  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    final response = await _dio.post('/categories', data: data);
    return response.data;
  }
  
  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/categories/$id', data: data);
    return response.data;
  }
  
  Future<void> deleteCategory(int id) async {
    await _dio.delete('/categories/$id');
  }
  
  // 预算
  Future<List<dynamic>> getBudgets() async {
    final response = await _dio.get('/budgets');
    return response.data;
  }
  
  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> data) async {
    final response = await _dio.post('/budgets', data: data);
    return response.data;
  }
  
  Future<Map<String, dynamic>> updateBudget(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/budgets/$id', data: data);
    return response.data;
  }
  
  Future<void> deleteBudget(int id) async {
    await _dio.delete('/budgets/$id');
  }
  
  Future<Map<String, dynamic>> getBudgetUsage(int id) async {
    final response = await _dio.get('/budgets/$id/usage');
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
  
  Future<Map<String, dynamic>> getStatsByDay({
    String? start,
    String? end,
    String? type,
  }) async {
    final params = <String, dynamic>{};
    if (start != null) params['start'] = start;
    if (end != null) params['end'] = end;
    if (type != null) params['type'] = type;
    
    final response = await _dio.get('/stats/by-day', queryParameters: params);
    return response.data;
  }
  
  // 标签
  Future<List<dynamic>> getTags() async {
    final response = await _dio.get('/tags');
    return response.data;
  }
  
  Future<Map<String, dynamic>> createTag(Map<String, dynamic> data) async {
    final response = await _dio.post('/tags', data: data);
    return response.data;
  }
  
  Future<Map<String, dynamic>> updateTag(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/tags/$id', data: data);
    return response.data;
  }
  
  Future<void> deleteTag(int id) async {
    await _dio.delete('/tags/$id');
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
