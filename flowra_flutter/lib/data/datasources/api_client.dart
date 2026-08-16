import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/auth/auth_gate.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flowra API Client
// Wraps all HTTP calls to the FastAPI backend.
// JWT is injected automatically via AuthInterceptor.
// ─────────────────────────────────────────────────────────────────────────────

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.flowra.app',
);

class FlowraApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;

  FlowraApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_baseUrl/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      _RetryInterceptor(_dio),
      LogInterceptor(requestBody: false, responseBody: false),
    ]);
  }

  // ── Auth helpers ─────────────────────────────────────────────────────────

  Future<void> setToken(String token) =>
      _storage.write(key: 'access_token', value: token);

  Future<void> clearToken() => _storage.delete(key: 'access_token');

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<UserModel> getMe() async {
    final res = await _dio.get('/users/me');
    return UserModel.fromJson(res.data);
  }

  Future<UserModel> updateMe(Map<String, dynamic> data) async {
    final res = await _dio.patch('/users/me', data: data);
    return UserModel.fromJson(res.data);
  }

  Future<UserModel> completeOnboarding(Map<String, dynamic> data) async {
    final res = await _dio.post('/users/me/onboarding', data: data);
    return UserModel.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final res = await _dio.get('/users/me/subscription');
    return res.data;
  }

  Future<void> deleteAccount() => _dio.delete('/users/me');

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<DashboardSummary> getDashboardSummary({int? year, int? month}) async {
    final res = await _dio.get('/dashboard/summary', queryParameters: {
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    });
    return DashboardSummary.fromJson(res.data);
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? transactionType,
    String? categoryId,
    String? accountId,
    bool? isNeed,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _dio.get('/transactions', queryParameters: {
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (transactionType != null) 'transaction_type': transactionType,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (isNeed != null) 'is_need': isNeed,
      if (search != null) 'search': search,
      'page': page,
      'page_size': pageSize,
    });
    return res.data;
  }

  Future<TransactionModel> createTransaction(Map<String, dynamic> data) async {
    final res = await _dio.post('/transactions', data: data);
    return TransactionModel.fromJson(res.data);
  }

  Future<TransactionModel> updateTransaction(
      String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/transactions/$id', data: data);
    return TransactionModel.fromJson(res.data);
  }

  Future<void> deleteTransaction(String id) => _dio.delete('/transactions/$id');

  // ── Accounts ──────────────────────────────────────────────────────────────

  Future<List<AccountModel>> getAccounts() async {
    final res = await _dio.get('/accounts');
    return (res.data as List).map((e) => AccountModel.fromJson(e)).toList();
  }

  Future<AccountModel> createAccount(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounts', data: data);
    return AccountModel.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getPlaidLinkToken() async {
    final res = await _dio.post('/accounts/plaid/link-token');
    return res.data;
  }

  Future<List<AccountModel>> exchangePlaidToken(
    String publicToken, {
    String? institutionName,
  }) async {
    final res = await _dio.post('/accounts/plaid/exchange', data: {
      'public_token': publicToken,
      if (institutionName != null) 'institution_name': institutionName,
    });
    return (res.data as List).map((e) => AccountModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> syncAccount(String accountId) async {
    final res = await _dio.post('/accounts/plaid/sync/$accountId');
    return res.data;
  }

  // ── Budgets ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final res = await _dio.get('/budgets');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> data) async {
    final res = await _dio.post('/budgets', data: data);
    return res.data;
  }

  Future<void> deleteBudget(String id) => _dio.delete('/budgets/$id');

  // ── Insights ──────────────────────────────────────────────────────────────

  Future<InsightModel> getMonthlyInsight(int year, int month) async {
    final res = await _dio.get('/insights/monthly/$year/$month');
    return InsightModel.fromJson(res.data);
  }

  Future<void> submitInsightFeedback(int year, int month, bool thumbsUp) =>
      _dio.post('/insights/monthly/$year/$month/feedback',
          data: {'thumbs_up': thumbsUp});

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotificationPrefs() async {
    final res = await _dio.get('/notifications/preferences');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> updateNotificationPref(
    String type,
    bool enabled, {
    String? timeOfDay,
  }) async {
    final res = await _dio.put(
      '/notifications/preferences/$type',
      data: {
        'enabled': enabled,
        if (timeOfDay != null) 'time_of_day': timeOfDay
      },
    );
    return res.data;
  }

  // ── Savings Goals ─────────────────────────────────────────────────────────

  Future<List<SavingsGoalModel>> getGoals() async {
    final res = await _dio.get('/goals');
    return (res.data as List).map((e) => SavingsGoalModel.fromJson(e)).toList();
  }

  Future<SavingsGoalModel> createGoal(Map<String, dynamic> data) async {
    final res = await _dio.post('/goals', data: data);
    return SavingsGoalModel.fromJson(res.data);
  }

  Future<SavingsGoalModel> updateGoal(
      String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/goals/$id', data: data);
    return SavingsGoalModel.fromJson(res.data);
  }

  Future<SavingsGoalModel> addGoalContribution(String id, double amount) async {
    final res =
        await _dio.post('/goals/$id/contribute', data: {'amount': amount});
    return SavingsGoalModel.fromJson(res.data);
  }

  Future<void> deleteGoal(String id) => _dio.delete('/goals/$id');

  // ── Bills ─────────────────────────────────────────────────────────────────

  Future<List<BillModel>> getBills() async {
    final res = await _dio.get('/bills');
    return (res.data as List).map((e) => BillModel.fromJson(e)).toList();
  }

  Future<BillModel> createBill(Map<String, dynamic> data) async {
    final res = await _dio.post('/bills', data: data);
    return BillModel.fromJson(res.data);
  }

  Future<BillModel> updateBill(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/bills/$id', data: data);
    return BillModel.fromJson(res.data);
  }

  Future<void> deleteBill(String id) => _dio.delete('/bills/$id');

  Future<List<BillPaymentModel>> getBillPayments(
      {int? year, int? month}) async {
    final res = await _dio.get('/bills/payments', queryParameters: {
      if (year != null) 'year': year,
      if (month != null) 'month': month,
    });
    return (res.data as List).map((e) => BillPaymentModel.fromJson(e)).toList();
  }

  Future<BillPaymentModel> markBillPaid(
    String billId, {
    double? amountPaid,
    DateTime? paidDate,
  }) async {
    final res = await _dio.post('/bills/$billId/pay', data: {
      if (amountPaid != null) 'amount_paid': amountPaid,
      'paid_date': (paidDate ?? DateTime.now()).toIso8601String(),
    });
    return BillPaymentModel.fromJson(res.data);
  }

  // ── Debt ──────────────────────────────────────────────────────────────────

  Future<DebtPlanModel?> getDebtPlan() async {
    try {
      final res = await _dio.get('/debt/plan');
      return DebtPlanModel.fromJson(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<DebtPlanModel> generateDebtPlan({
    required String strategy,
    required double monthlyExtraPayment,
  }) async {
    final res = await _dio.post('/debt/plan', data: {
      'strategy': strategy,
      'monthly_extra_payment': monthlyExtraPayment,
    });
    return DebtPlanModel.fromJson(res.data);
  }
}

// ── Auth interceptor ──────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  _AuthInterceptor(this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token expired — clear and signal re-auth needed
      _storage.delete(key: 'access_token');
      AuthGate.notifyUnauthorized();
    }
    handler.next(err);
  }
}

// ── Retry interceptor ─────────────────────────────────────────────────────────

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final shouldRetry = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;
    if (shouldRetry) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {}
    }
    handler.next(err);
  }
}
