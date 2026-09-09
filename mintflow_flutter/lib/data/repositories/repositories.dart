import '../datasources/api_client.dart';
import '../datasources/local_cache.dart';
import '../models/models.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// Repositories — thin layer between cubits and the API client.
// Responsibilities: caching, error normalization, cache invalidation.
// Each repository uses MintflowCache for TTL-based local caching.
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// UserRepository
// ═══════════════════════════════════════════════════════════════════════════

class UserRepository {
  final MintflowApiClient _api;
  UserRepository(this._api);

  Future<UserModel> getMe({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = MintflowCache.get<String>(CacheKeys.userProfile);
      if (cached != null) {
        return UserModel.fromJson(jsonDecode(cached));
      }
    }
    final user = await _api.getMe();
    await MintflowCache.set(
      CacheKeys.userProfile,
      jsonEncode(_userToJson(user)),
      ttl: const Duration(hours: 1),
    );
    return user;
  }

  Future<UserModel> updateMe(Map<String, dynamic> data) async {
    final user = await _api.updateMe(data);
    await MintflowCache.set(CacheKeys.userProfile, jsonEncode(_userToJson(user)));
    return user;
  }

  Future<UserModel> completeOnboarding(Map<String, dynamic> data) async {
    final user = await _api.completeOnboarding(data);
    await MintflowCache.set(CacheKeys.userProfile, jsonEncode(_userToJson(user)));
    return user;
  }

  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await MintflowCache.clearAll();
  }

  Map<String, dynamic> _userToJson(UserModel u) => {
        'id': u.id,
        'email': u.email,
        'full_name': u.fullName,
        'avatar_url': u.avatarUrl,
        'subscription_tier': u.subscriptionTier.name,
        'trial_ends_at': u.trialEndsAt?.toIso8601String(),
        'locale': u.locale,
        'currency': u.currency,
        'monthly_income': u.monthlyIncome?.toString(),
        'created_at': u.createdAt.toIso8601String(),
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// DashboardRepository
// ═══════════════════════════════════════════════════════════════════════════

class DashboardRepository {
  final MintflowApiClient _api;
  DashboardRepository(this._api);

  Future<DashboardSummary> getSummary({
    int? year,
    int? month,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final cacheKey = '${CacheKeys.dashboardSummary}_${y}_$m';
    final isCurrentMonth = y == now.year && m == now.month;

    if (!forceRefresh && isCurrentMonth) {
      final cached = MintflowCache.get<Map>(cacheKey);
      if (cached != null) {
        return DashboardSummary.fromJson(Map<String, dynamic>.from(cached));
      }
    }

    final summary = await _api.getDashboardSummary(year: y, month: m);

    if (isCurrentMonth) {
      // Cache current month for 10 minutes — stale quickly due to transactions
      await MintflowCache.set(
        cacheKey,
        _summaryToMap(summary),
        ttl: const Duration(minutes: 10),
      );
    }
    return summary;
  }

  Map<String, dynamic> _summaryToMap(DashboardSummary s) => {
        'period_key': s.periodKey,
        'total_income': s.totalIncome.toString(),
        'total_spent': s.totalSpent.toString(),
        'total_saved': s.totalSaved.toString(),
        'savings_rate_pct': s.savingsRatePct,
        'needs_total': s.needsTotal.toString(),
        'wants_total': s.wantsTotal.toString(),
        'needs_pct': s.needsPct,
        'wants_pct': s.wantsPct,
        'budget_amount': s.budgetAmount?.toString(),
        'budget_pct_used': s.budgetPctUsed,
        'budget_remaining': s.budgetRemaining?.toString(),
        'days_in_period': s.daysInPeriod,
        'days_elapsed': s.daysElapsed,
        'days_remaining': s.daysRemaining,
        'projected_spend': s.projectedSpend?.toString(),
        'spending_by_category': s.spendingByCategory
            .map((c) => {
                  'category_id': c.categoryId,
                  'category_name': c.categoryName,
                  'category_color': c.categoryColor,
                  'total': c.total.toString(),
                  'pct_of_total': c.pctOfTotal,
                  'is_need': c.isNeed,
                  'transaction_count': c.transactionCount,
                })
            .toList(),
        'top_insight': s.topInsight,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// TransactionRepository
// ═══════════════════════════════════════════════════════════════════════════

class TransactionRepository {
  final MintflowApiClient _api;
  TransactionRepository(this._api);

  Future<TransactionListResult> getTransactions({
    String? filter, // 'all' | 'expenses' | 'income' | 'needs' | 'wants'
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    // Map filter → API params
    String? txType;
    bool? isNeed;
    if (filter == 'expenses') txType = 'expense';
    if (filter == 'income') txType = 'income';
    if (filter == 'needs') isNeed = true;
    if (filter == 'wants') isNeed = false;

    final raw = await _api.getTransactions(
      transactionType: txType,
      isNeed: isNeed,
      search: search,
      page: page,
      pageSize: pageSize,
    );

    final items = (raw['transactions'] as List)
        .map((e) => TransactionModel.fromJson(e))
        .toList();

    return TransactionListResult(
      items: items,
      total: raw['total'] as int,
      page: raw['page'] as int,
      totalPages: raw['total_pages'] as int,
    );
  }

  Future<TransactionModel> createTransaction({
    required double amount,
    required String transactionType,
    required DateTime date,
    String? merchantName,
    String? description,
    String? categoryId,
    String? accountId,
    bool? isNeed,
    String? notes,
    String? incomeSource,
  }) async {
    final tx = await _api.createTransaction({
      'amount': amount,
      'transaction_type': transactionType,
      'date': date.toIso8601String(),
      if (merchantName != null) 'merchant_name': merchantName,
      if (description != null) 'description': description,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (isNeed != null) 'is_need': isNeed,
      if (notes != null) 'notes': notes,
      if (incomeSource != null) 'income_source': incomeSource,
    });
    // Invalidate dashboard cache — new transaction changes totals
    await MintflowCache.invalidateDashboard();
    return tx;
  }

  Future<TransactionModel> updateTransaction(
    String id,
    Map<String, dynamic> data,
  ) async {
    final tx = await _api.updateTransaction(id, data);
    await MintflowCache.invalidateDashboard();
    return tx;
  }

  Future<void> deleteTransaction(String id) async {
    await _api.deleteTransaction(id);
    await MintflowCache.invalidateDashboard();
  }
}

class TransactionListResult {
  final List<TransactionModel> items;
  final int total, page, totalPages;
  const TransactionListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.totalPages,
  });
  bool get hasMore => page < totalPages;
}

// ═══════════════════════════════════════════════════════════════════════════
// GoalRepository
// ═══════════════════════════════════════════════════════════════════════════

class GoalRepository {
  final MintflowApiClient _api;
  GoalRepository(this._api);

  Future<List<SavingsGoalModel>> getGoals({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = MintflowCache.get<List>(CacheKeys.goals);
      if (cached != null) {
        return cached
            .map((e) => SavingsGoalModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    final goals = await _api.getGoals();
    await MintflowCache.set(
      CacheKeys.goals,
      goals.map(_goalToMap).toList(),
      ttl: const Duration(minutes: 5),
    );
    return goals;
  }

  Future<SavingsGoalModel> createGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? linkedAccountId,
    String? icon,
    String? color,
  }) async {
    final goal = await _api.createGoal({
      'name': name,
      'target_amount': targetAmount,
      'current_amount': 0.0,
      if (targetDate != null) 'target_date': targetDate.toIso8601String(),
      if (linkedAccountId != null) 'linked_account_id': linkedAccountId,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
    });
    await MintflowCache.invalidateGoals();
    return goal;
  }

  Future<SavingsGoalModel> contribute(String id, double amount) async {
    final goal = await _api.addGoalContribution(id, amount);
    await MintflowCache.invalidateGoals();
    return goal;
  }

  Future<void> deleteGoal(String id) async {
    await _api.deleteGoal(id);
    await MintflowCache.invalidateGoals();
  }

  Map<String, dynamic> _goalToMap(SavingsGoalModel g) => {
        'id': g.id,
        'user_id': g.userId,
        'name': g.name,
        'target_amount': g.targetAmount.toString(),
        'current_amount': g.currentAmount.toString(),
        'target_date': g.targetDate?.toIso8601String(),
        'linked_account_id': g.linkedAccountId,
        'icon': g.icon,
        'color': g.color,
        'status': g.status.name,
        'ai_suggestion': g.aiSuggestion,
        'created_at': g.createdAt.toIso8601String(),
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// BillRepository
// ═══════════════════════════════════════════════════════════════════════════

class BillRepository {
  final MintflowApiClient _api;
  BillRepository(this._api);

  Future<List<BillModel>> getBills({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = MintflowCache.get<List>(CacheKeys.bills);
      if (cached != null) {
        return cached
            .map((e) => BillModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    final bills = await _api.getBills();
    await MintflowCache.set(
      CacheKeys.bills,
      bills.map(_billToMap).toList(),
      ttl: const Duration(minutes: 5),
    );
    return bills;
  }

  Future<List<BillPaymentModel>> getPayments({int? year, int? month}) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    final key = '${CacheKeys.billPayments}_${y}_$m';
    final cached = MintflowCache.get<List>(key);
    if (cached != null) {
      return cached
          .map((e) => BillPaymentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final payments = await _api.getBillPayments(year: y, month: m);
    await MintflowCache.set(key, payments.map(_paymentToMap).toList(),
        ttl: const Duration(minutes: 5));
    return payments;
  }

  Future<BillModel> createBill({
    required String name,
    double? amount,
    required int dueDay,
    String? categoryId,
    bool isAutopay = false,
  }) async {
    final bill = await _api.createBill({
      'name': name,
      'due_day': dueDay,
      'is_autopay': isAutopay,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
    });
    await MintflowCache.invalidateBills();
    return bill;
  }

  Future<BillPaymentModel> markPaid(
    String billId, {
    double? amountPaid,
  }) async {
    final payment = await _api.markBillPaid(billId, amountPaid: amountPaid);
    await MintflowCache.invalidateBills();
    return payment;
  }

  Future<void> deleteBill(String id) async {
    await _api.deleteBill(id);
    await MintflowCache.invalidateBills();
  }

  Map<String, dynamic> _billToMap(BillModel b) => {
        'id': b.id,
        'user_id': b.userId,
        'name': b.name,
        'amount': b.amount?.toString(),
        'due_day': b.dueDay,
        'category_id': b.categoryId,
        'is_autopay': b.isAutopay,
        'is_active': b.isActive,
        'created_at': b.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _paymentToMap(BillPaymentModel p) => {
        'id': p.id,
        'bill_id': p.billId,
        'user_id': p.userId,
        'amount_paid': p.amountPaid?.toString(),
        'due_date': p.dueDate.toIso8601String(),
        'paid_date': p.paidDate?.toIso8601String(),
        'status': p.status.name,
        'transaction_id': p.transactionId,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// InsightRepository
// ═══════════════════════════════════════════════════════════════════════════

class InsightRepository {
  final MintflowApiClient _api;
  InsightRepository(this._api);

  Future<InsightModel> getMonthlyInsight({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final key = CacheKeys.insight('$year-${month.toString().padLeft(2, '0')}');
    if (!forceRefresh) {
      final cached = MintflowCache.get<Map>(key);
      if (cached != null) {
        return InsightModel.fromJson(Map<String, dynamic>.from(cached));
      }
    }
    final insight = await _api.getMonthlyInsight(year, month);
    await MintflowCache.set(
        key,
        {
          'id': insight.id,
          'period_key': insight.periodKey,
          'content': {
            'summary': insight.summary,
            'insights': insight.insights
                .map((i) => {
                      'type': i.type,
                      'title': i.title,
                      'body': i.body,
                      'action_label': i.actionLabel,
                      'action_type': i.actionType,
                    })
                .toList(),
            'recommendations': insight.recommendations
                .map((r) => {
                      'type': r.type,
                      'title': r.title,
                      'body': r.body,
                      'action_label': r.actionLabel,
                      'action_type': r.actionType,
                    })
                .toList(),
          },
          'thumbs_up': insight.thumbsUp,
          'generated_at': insight.generatedAt.toIso8601String(),
        },
        ttl: const Duration(hours: 6));
    return insight;
  }

  Future<void> submitFeedback(int year, int month, bool thumbsUp) =>
      _api.submitInsightFeedback(year, month, thumbsUp);
}
