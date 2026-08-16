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
  
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    _dio.options.baseUrl = '$url/api';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
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
  
  // 导入导出
  Future<Map<String, dynamic>> uploadImport(String source, String filePath) async {
    final formData = FormData.fromMap({
      'source': source,
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/imports/upload', data: formData);
    return response.data;
  }

  Future<List<dynamic>> getImports() async {
    final response = await _dio.get('/imports');
    return response.data;
  }

  Future<Map<String, dynamic>> getImportById(int id) async {
    final response = await _dio.get('/imports/$id');
    return response.data;
  }

  Future<List<dynamic>> getImportItems(int id) async {
    final response = await _dio.get('/imports/$id/items');
    return response.data;
  }

  Future<Map<String, dynamic>> confirmImport(int id) async {
    final response = await _dio.post('/imports/$id/confirm');
    return response.data;
  }

  Future<void> deleteImport(int id) async {
    await _dio.delete('/imports/$id');
  }

  Future<List<int>> exportTransactions({
    String? startDate,
    String? endDate,
    String? format,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (format != null) params['format'] = format;

    final response = await _dio.get<List<int>>(
      '/export/transactions',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<List<int>> exportAccounts() async {
    final response = await _dio.get<List<int>>(
      '/export/accounts',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<List<int>> exportCategories() async {
    final response = await _dio.get<List<int>>(
      '/export/categories',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  // 信用账单
  Future<List<dynamic>> getCreditBills() async {
    final response = await _dio.get('/credit-bills');
    return response.data;
  }

  Future<Map<String, dynamic>> generateCreditBills({int? year, int? month}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;

    final response = await _dio.post('/credit-bills/generate', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getCreditBillById(int id) async {
    final response = await _dio.get('/credit-bills/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> getCreditBillSummary() async {
    final response = await _dio.get('/credit-bills/summary');
    return response.data;
  }

  Future<Map<String, dynamic>> payCreditBill(int id, Map<String, dynamic> data) async {
    final response = await _dio.post('/credit-bills/$id/pay', data: data);
    return response.data;
  }

  // 借贷
  Future<List<dynamic>> getDebts({String? type, String? status}) async {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;

    final response = await _dio.get('/debts', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getDebtSummary() async {
    final response = await _dio.get('/debts/summary');
    return response.data;
  }

  Future<Map<String, dynamic>> createDebt(Map<String, dynamic> data) async {
    final response = await _dio.post('/debts', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateDebt(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/debts/$id', data: data);
    return response.data;
  }

  Future<void> deleteDebt(int id) async {
    await _dio.delete('/debts/$id');
  }

  Future<List<dynamic>> getDebtRepayments(int debtId) async {
    final response = await _dio.get('/debts/$debtId/repayments');
    return response.data;
  }

  Future<Map<String, dynamic>> addRepayment(int debtId, Map<String, dynamic> data) async {
    final response = await _dio.post('/debts/$debtId/repayments', data: data);
    return response.data;
  }

  // 储蓄
  Future<List<dynamic>> getSavingsGoals({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _dio.get('/savings', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> createSavingsGoal(Map<String, dynamic> data) async {
    final response = await _dio.post('/savings', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getSavingsGoalById(int id) async {
    final response = await _dio.get('/savings/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> updateSavingsGoal(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/savings/$id', data: data);
    return response.data;
  }

  Future<void> deleteSavingsGoal(int id) async {
    await _dio.delete('/savings/$id');
  }

  Future<Map<String, dynamic>> depositToGoal(int id, Map<String, dynamic> data) async {
    final response = await _dio.post('/savings/$id/deposit', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> abandonGoal(int id) async {
    final response = await _dio.post('/savings/$id/abandon');
    return response.data;
  }

  // 周期交易
  Future<List<dynamic>> getRecurringTransactions() async {
    final response = await _dio.get('/recurring');
    return response.data;
  }

  Future<Map<String, dynamic>> createRecurring(Map<String, dynamic> data) async {
    final response = await _dio.post('/recurring', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getRecurringById(int id) async {
    final response = await _dio.get('/recurring/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> updateRecurring(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/recurring/$id', data: data);
    return response.data;
  }

  Future<void> deleteRecurring(int id) async {
    await _dio.delete('/recurring/$id');
  }

  Future<Map<String, dynamic>> generateFromRecurring(int id) async {
    final response = await _dio.post('/recurring/$id/generate');
    return response.data;
  }

  Future<List<dynamic>> getRecurringLogs(int id) async {
    final response = await _dio.get('/recurring/$id/logs');
    return response.data;
  }

  Future<Map<String, dynamic>> processRecurring() async {
    final response = await _dio.post('/recurring/process');
    return response.data;
  }

  // 报销
  Future<List<dynamic>> getReimbursements({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;

    final response = await _dio.get('/reimbursements', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> createReimbursement(Map<String, dynamic> data) async {
    final response = await _dio.post('/reimbursements', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> getReimbursementById(int id) async {
    final response = await _dio.get('/reimbursements/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> updateReimbursement(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/reimbursements/$id', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> submitReimbursement(int id) async {
    final response = await _dio.post('/reimbursements/$id/submit');
    return response.data;
  }

  Future<Map<String, dynamic>> approveReimbursement(int id) async {
    final response = await _dio.post('/reimbursements/$id/approve');
    return response.data;
  }

  Future<Map<String, dynamic>> receiveReimbursement(int id, Map<String, dynamic> data) async {
    final response = await _dio.post('/reimbursements/$id/receive', data: data);
    return response.data;
  }

  Future<void> deleteReimbursement(int id) async {
    await _dio.delete('/reimbursements/$id');
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

  Future<void> markNotificationRead(int id) async {
    await _dio.put('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.put('/notifications/read-all');
  }

  Future<void> triggerNotificationCheck() async {
    await _dio.post('/notifications/check');
  }

  // AI 助手
  Future<Map<String, dynamic>> parseTransactionText(String text) async {
    final response = await _dio.post('/ai/parse', data: {'text': text});
    return response.data;
  }

  Future<Map<String, dynamic>> suggestCategory(Map<String, dynamic> data) async {
    final response = await _dio.post('/ai/suggest-category', data: data);
    return response.data;
  }

  Future<List<dynamic>> getAISuggestions({String? type, String? status}) async {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;

    final response = await _dio.get('/ai/suggestions', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> acceptAISuggestion(int id) async {
    final response = await _dio.post('/ai/suggestions/$id/accept');
    return response.data;
  }

  Future<Map<String, dynamic>> rejectAISuggestion(int id) async {
    final response = await _dio.post('/ai/suggestions/$id/reject');
    return response.data;
  }

  Future<Map<String, dynamic>> batchActionAISuggestions(Map<String, dynamic> data) async {
    final response = await _dio.post('/ai/suggestions/batch-action', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> triggerAIAnalysis() async {
    final response = await _dio.post('/ai/analyze');
    return response.data;
  }

  Future<Map<String, dynamic>> getAISettings() async {
    final response = await _dio.get('/ai/settings');
    return response.data;
  }

  Future<Map<String, dynamic>> updateAISettings(Map<String, dynamic> data) async {
    final response = await _dio.put('/ai/settings', data: data);
    return response.data;
  }

  Future<void> deleteAISettings() async {
    await _dio.delete('/ai/settings');
  }

  Future<List<dynamic>> getAIProviders() async {
    final response = await _dio.get('/ai/providers');
    return response.data;
  }

  Future<Map<String, dynamic>> testAIConnection() async {
    final response = await _dio.post('/ai/test');
    return response.data;
  }

  // 家庭协作
  Future<Map<String, dynamic>> getCurrentFamily() async {
    final response = await _dio.get('/families/current');
    return response.data;
  }

  Future<Map<String, dynamic>> updateFamily(Map<String, dynamic> data) async {
    final response = await _dio.put('/families/current', data: data);
    return response.data;
  }

  Future<List<dynamic>> getFamilyMembers() async {
    final response = await _dio.get('/families/members');
    return response.data;
  }

  Future<Map<String, dynamic>> addFamilyMember(Map<String, dynamic> data) async {
    final response = await _dio.post('/families/members', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateMemberRole(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/families/members/$id', data: data);
    return response.data;
  }

  Future<void> removeFamilyMember(int id) async {
    await _dio.delete('/families/members/$id');
  }

  Future<Map<String, dynamic>> joinFamily(Map<String, dynamic> data) async {
    final response = await _dio.post('/families/join', data: data);
    return response.data;
  }

  // 规则引擎
  Future<List<dynamic>> getRules() async {
    final response = await _dio.get('/rules');
    return response.data;
  }

  Future<Map<String, dynamic>> createRule(Map<String, dynamic> data) async {
    final response = await _dio.post('/rules', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateRule(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/rules/$id', data: data);
    return response.data;
  }

  Future<void> deleteRule(int id) async {
    await _dio.delete('/rules/$id');
  }

  Future<Map<String, dynamic>> testRule(Map<String, dynamic> data) async {
    final response = await _dio.post('/rules/test', data: data);
    return response.data;
  }
}
