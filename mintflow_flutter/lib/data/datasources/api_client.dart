import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/auth/auth_gate.dart';
import '../models/models.dart';
import 'token_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow API Client
// Wraps all HTTP calls to the FastAPI backend.
// JWT is injected automatically via AuthInterceptor; 401 triggers one refresh.
// ─────────────────────────────────────────────────────────────────────────────

String resolveApiBaseUrl() {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine.replaceAll(RegExp(r'/$'), '');
  final fromEnv = (dotenv.env['API_BASE_URL'] ?? '').trim();
  if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
  return 'https://api.mintflow.app';
}

class AuthTokensResult {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UserModel user;

  const AuthTokensResult({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthTokensResult.fromJson(Map<String, dynamic> json) =>
      AuthTokensResult(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: (json['token_type'] as String?) ?? 'bearer',
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class MintflowApiClient {
  late final Dio _dio;
  final TokenStore _tokens;

  /// Separate client for refresh — avoids interceptor recursion.
  late final Dio _refreshDio;

  MintflowApiClient({required TokenStore tokenStore}) : _tokens = tokenStore {
    final base = '${resolveApiBaseUrl()}/v1';
    final options = BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = Dio(options);
    _refreshDio = Dio(options);
    _dio.interceptors.addAll([
      _AuthInterceptor(_tokens, _refreshDio),
      _RetryInterceptor(_dio),
      LogInterceptor(requestBody: false, responseBody: false),
    ]);
  }

  TokenStore get tokens => _tokens;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<AuthTokensResult> signup({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await _dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
    });
    final result = AuthTokensResult.fromJson(res.data as Map<String, dynamic>);
    await _tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  Future<AuthTokensResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final result = AuthTokensResult.fromJson(res.data as Map<String, dynamic>);
    await _tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  Future<AuthTokensResult> google({required String idToken}) async {
    final res = await _dio.post('/auth/google', data: {
      'id_token': idToken,
    });
    final result = AuthTokensResult.fromJson(res.data as Map<String, dynamic>);
    await _tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  Future<AuthTokensResult> apple({
    required String identityToken,
    String? email,
    String? fullName,
  }) async {
    final res = await _dio.post('/auth/apple', data: {
      'identity_token': identityToken,
      if (email != null && email.isNotEmpty) 'email': email,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
    });
    final result = AuthTokensResult.fromJson(res.data as Map<String, dynamic>);
    await _tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  Future<AuthTokensResult> refresh({required String refreshToken}) async {
    final res = await _refreshDio.post('/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    final result = AuthTokensResult.fromJson(res.data as Map<String, dynamic>);
    await _tokens.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    return result;
  }

  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    try {
      await _dio.post('/auth/logout', data: {
        if (refresh != null) 'refresh_token': refresh,
      });
    } catch (_) {
      // Always clear local session even if revoke fails
    }
    await _tokens.clear();
  }

  Future<void> forgotPassword({required String email}) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _dio.post('/auth/reset-password', data: {
      'token': token,
      'password': password,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> logoutAll() async {
    await _dio.post('/auth/logout-all');
    await _tokens.clear();
  }

  Future<UserModel> getAuthMe() async {
    final res = await _dio.get('/auth/me');
    return UserModel.fromJson(res.data as Map<String, dynamic>);
  }

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

  /// Pro-gated CSV of all transactions. Returns raw bytes + suggested filename.
  Future<({List<int> bytes, String filename})> exportTransactionsCsv() async {
    final res = await _dio.get<List<int>>(
      '/users/me/export/transactions.csv',
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = res.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    final filename = match?.group(1) ??
        'mintflow-transactions-${DateTime.now().toUtc().toIso8601String().substring(0, 10).replaceAll('-', '')}.csv';
    return (bytes: res.data ?? <int>[], filename: filename);
  }

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

  Future<void> unlinkAccount(String accountId) async {
    await _dio.delete('/accounts/$accountId');
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

  // ── Recurring subscriptions (merchant tracker) ────────────────────────────

  Future<RecurringSubscriptionList> getRecurringSubscriptions({
    String status = 'active',
  }) async {
    final res = await _dio.get(
      '/recurring-subscriptions',
      queryParameters: {'status': status},
    );
    return RecurringSubscriptionList.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<Map<String, dynamic>> detectRecurringSubscriptions() async {
    final res = await _dio.post('/recurring-subscriptions/detect');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<RecurringSubscriptionModel> updateRecurringSubscription(
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.patch('/recurring-subscriptions/$id', data: data);
    return RecurringSubscriptionModel.fromJson(
      Map<String, dynamic>.from(res.data as Map),
    );
  }

  Future<void> dismissRecurringSubscription(String id) =>
      _dio.delete('/recurring-subscriptions/$id');
}

// ── Auth interceptor ──────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final TokenStore _tokens;
  final Dio _refreshDio;

  /// Shared lock so concurrent 401s only trigger one refresh.
  static Completer<bool>? _refreshLock;

  _AuthInterceptor(this._tokens, this._refreshDio);

  static const _skipAuthPaths = {
    '/auth/signup',
    '/auth/login',
    '/auth/google',
    '/auth/apple',
    '/auth/refresh',
    '/auth/forgot-password',
    '/auth/reset-password',
  };

  bool _isPublicAuth(String path) =>
      _skipAuthPaths.any((p) => path.endsWith(p) || path.contains(p));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicAuth(options.path)) {
      final token = await _tokens.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final path = err.requestOptions.path;
    // Public auth endpoints return 401 for bad credentials — do not clear session.
    if (_isPublicAuth(path)) {
      return handler.next(err);
    }
    if (err.requestOptions.extra['auth_retried'] == true) {
      await _forceLogout();
      return handler.next(err);
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      await _forceLogout();
      return handler.next(err);
    }

    try {
      final opts = err.requestOptions;
      opts.extra['auth_retried'] = true;
      final token = await _tokens.readAccessToken();
      if (token != null) {
        opts.headers['Authorization'] = 'Bearer $token';
      }
      final response = await _refreshDio.fetch(opts);
      return handler.resolve(response);
    } catch (_) {
      await _forceLogout();
      return handler.next(err);
    }
  }

  Future<bool> _refreshOnce() async {
    if (_refreshLock != null) {
      return _refreshLock!.future;
    }
    final lock = Completer<bool>();
    _refreshLock = lock;
    try {
      final refresh = await _tokens.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        lock.complete(false);
        return false;
      }
      final res = await _refreshDio.post('/auth/refresh', data: {
        'refresh_token': refresh,
      });
      final data = res.data as Map<String, dynamic>;
      await _tokens.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      lock.complete(true);
      return true;
    } catch (_) {
      lock.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }

  Future<void> _forceLogout() async {
    await _tokens.clear();
    AuthGate.notifyUnauthorized();
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
