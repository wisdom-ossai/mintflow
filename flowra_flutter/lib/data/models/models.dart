// ─────────────────────────────────────────────────────────────────────────────
// Flowra domain models
// Pure Dart — no Flutter dependency. Serializable with json_annotation.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TransactionType { income, expense, creditPayment, transfer }

enum TransactionSource { plaid, manual, ocr }

enum AccountType { bank, creditCard, cash, wallet, loan }

enum SubscriptionTier { seed, growth, pro }

enum BudgetPeriod { monthly, annual }

enum GoalStatus { active, completed, paused }

enum BillStatus { paid, unpaid, overdue }

enum DebtStrategy { snowball, avalanche }

enum IncomeSource { salary, freelance, rental, business, other }

enum LoanType { student, auto, mortgage, personal, other }

// ── User ──────────────────────────────────────────────────────────────────────

class UserModel extends Equatable {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final SubscriptionTier subscriptionTier;
  final DateTime? trialEndsAt;
  final String locale;
  final String currency;
  final double? monthlyIncome;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    required this.subscriptionTier,
    this.trialEndsAt,
    required this.locale,
    required this.currency,
    this.monthlyIncome,
    required this.createdAt,
  });

  bool get isTrialActive =>
      trialEndsAt != null && DateTime.now().isBefore(trialEndsAt!);

  SubscriptionTier get effectiveTier =>
      isTrialActive ? SubscriptionTier.pro : subscriptionTier;

  /// Proxy for incomplete onboarding when backend has no dedicated flag.
  bool get hasCompletedOnboarding =>
      fullName != null &&
      fullName!.trim().isNotEmpty &&
      monthlyIncome != null;

  /// Keep in sync with backend `User.has_feature` — client must never unlock more.
  bool hasFeature(String feature) {
    final tier = effectiveTier;
    const growthPro = [SubscriptionTier.growth, SubscriptionTier.pro];
    const proOnly = [SubscriptionTier.pro];
    const map = <String, List<SubscriptionTier>>{
      // Growth+
      'bank_sync': growthPro,
      'ai_categorization': growthPro,
      'ai_insights': growthPro,
      'needs_wants': growthPro,
      'spending_trends': growthPro,
      'annual_summary': growthPro,
      'smart_nudges': growthPro,
      'subscription_tracker': growthPro,
      'shareable_card': growthPro,
      'credit_tracking': growthPro,
      'unlimited_goals': growthPro,
      'unlimited_bills': growthPro,
      'income_breakdown': growthPro,
      'category_budgets': growthPro,
      // Pro
      'unlimited_accounts': proOnly,
      'credit_utilization': proOnly,
      'ai_recommendations': proOnly,
      'receipt_ocr': proOnly,
      'custom_categories': proOnly,
      'csv_export': proOnly,
      'rollover_budgets': proOnly,
      'debt_payoff_plan': proOnly,
    };
    return map[feature]?.contains(tier) ?? false;
  }

  String get displayName => fullName ?? email.split('@').first;

  String get initials {
    final parts = (fullName ?? email).split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return (fullName ?? email).substring(0, 2).toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        email: json['email'],
        fullName: json['full_name'],
        avatarUrl: json['avatar_url'],
        subscriptionTier: SubscriptionTier.values.firstWhere(
          (e) => e.name == json['subscription_tier'],
          orElse: () => SubscriptionTier.seed,
        ),
        trialEndsAt: json['trial_ends_at'] != null
            ? DateTime.parse(json['trial_ends_at'])
            : null,
        locale: json['locale'] ?? 'en-US',
        currency: json['currency'] ?? 'USD',
        monthlyIncome: json['monthly_income'] != null
            ? double.parse(json['monthly_income'].toString())
            : null,
        createdAt: DateTime.parse(json['created_at']),
      );

  @override
  List<Object?> get props => [id, email, subscriptionTier, trialEndsAt];
}

// ── Category ──────────────────────────────────────────────────────────────────

class CategoryModel extends Equatable {
  final String id;
  final String? userId;
  final String name;
  final String? icon;
  final String? color;
  final bool isCustom;

  const CategoryModel({
    required this.id,
    this.userId,
    required this.name,
    this.icon,
    this.color,
    required this.isCustom,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'],
        userId: json['user_id'],
        name: json['name'],
        icon: json['icon'],
        color: json['color'],
        isCustom: json['is_custom'] ?? false,
      );

  @override
  List<Object?> get props => [id, name];
}

// ── Transaction ───────────────────────────────────────────────────────────────

class TransactionModel extends Equatable {
  final String id;
  final String userId;
  final String? accountId;
  final String? categoryId;
  final CategoryModel? category;
  final double amount;
  final TransactionType transactionType;
  final bool? isNeed;
  final String? description;
  final String? merchantName;
  final DateTime date;
  final TransactionSource source;
  final bool isCreditCardPayment;
  final bool isRecurring;
  final String? notes;
  final bool aiCategorized;
  final bool countsAsSpend;
  final IncomeSource? incomeSource;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    this.accountId,
    this.categoryId,
    this.category,
    required this.amount,
    required this.transactionType,
    this.isNeed,
    this.description,
    this.merchantName,
    required this.date,
    required this.source,
    required this.isCreditCardPayment,
    required this.isRecurring,
    this.notes,
    required this.aiCategorized,
    required this.countsAsSpend,
    this.incomeSource,
    required this.createdAt,
  });

  String get displayName => merchantName ?? description ?? 'Transaction';

  bool get isIncome => transactionType == TransactionType.income;

  String get formattedAmount {
    final prefix = isIncome ? '+' : '-';
    return '$prefix\$${amount.toStringAsFixed(2)}';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel(
        id: json['id'],
        userId: json['user_id'],
        accountId: json['account_id'],
        categoryId: json['category_id'],
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'])
            : null,
        amount: double.parse(json['amount'].toString()),
        transactionType: TransactionType.values.firstWhere(
          (e) => e.name == _camelCase(json['transaction_type']),
          orElse: () => TransactionType.expense,
        ),
        isNeed: json['is_need'],
        description: json['description'],
        merchantName: json['merchant_name'],
        date: DateTime.parse(json['date']),
        source: TransactionSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => TransactionSource.manual,
        ),
        isCreditCardPayment: json['is_credit_card_payment'] ?? false,
        isRecurring: json['is_recurring'] ?? false,
        notes: json['notes'],
        aiCategorized: json['ai_categorized'] ?? false,
        countsAsSpend: json['counts_as_spend'] ?? true,
        incomeSource: json['income_source'] != null
            ? IncomeSource.values.firstWhere(
                (e) => e.name == json['income_source'],
                orElse: () => IncomeSource.other,
              )
            : null,
        createdAt: DateTime.parse(json['created_at']),
      );

  @override
  List<Object?> get props => [id, amount, date, transactionType];
}

String _camelCase(String s) {
  final parts = s.split('_');
  return parts[0] +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

// ── Account ───────────────────────────────────────────────────────────────────

class AccountModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? institutionName;
  final AccountType accountType;
  final String currency;
  final double? balance;
  final double? creditLimit;
  final double? outstandingBalance;
  final double? availableCredit;
  final double? creditUtilizationPct;
  final int? statementDay;
  final int? dueDay;
  // Loan fields
  final double? principalBalance;
  final double? interestRate;
  final double? monthlyPayment;
  final int? remainingTermMonths;
  final LoanType? loanType;
  final String? lenderName;
  final bool isActive;
  final DateTime? lastSyncedAt;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    this.institutionName,
    required this.accountType,
    required this.currency,
    this.balance,
    this.creditLimit,
    this.outstandingBalance,
    this.availableCredit,
    this.creditUtilizationPct,
    this.statementDay,
    this.dueDay,
    this.principalBalance,
    this.interestRate,
    this.monthlyPayment,
    this.remainingTermMonths,
    this.loanType,
    this.lenderName,
    required this.isActive,
    this.lastSyncedAt,
  });

  bool get isCreditCard => accountType == AccountType.creditCard;
  bool get isLoan => accountType == AccountType.loan;
  bool get isBank => accountType == AccountType.bank;

  double get currentBalance {
    if (isCreditCard) return outstandingBalance ?? 0;
    if (isLoan) return principalBalance ?? 0;
    return balance ?? 0;
  }

  bool get hasHighUtilization =>
      creditUtilizationPct != null && creditUtilizationPct! > 70;

  factory AccountModel.fromJson(Map<String, dynamic> json) => AccountModel(
        id: json['id'],
        userId: json['user_id'],
        name: json['name'],
        institutionName: json['institution_name'],
        accountType: AccountType.values.firstWhere(
          (e) => e.name == _camelCase(json['account_type']),
          orElse: () => AccountType.bank,
        ),
        currency: json['currency'] ?? 'USD',
        balance: json['balance'] != null
            ? double.parse(json['balance'].toString())
            : null,
        creditLimit: json['credit_limit'] != null
            ? double.parse(json['credit_limit'].toString())
            : null,
        outstandingBalance: json['outstanding_balance'] != null
            ? double.parse(json['outstanding_balance'].toString())
            : null,
        availableCredit: json['available_credit'] != null
            ? double.parse(json['available_credit'].toString())
            : null,
        creditUtilizationPct: json['credit_utilization_pct']?.toDouble(),
        statementDay: json['statement_day'],
        dueDay: json['due_day'],
        principalBalance: json['principal_balance'] != null
            ? double.parse(json['principal_balance'].toString())
            : null,
        interestRate: json['interest_rate'] != null
            ? double.parse(json['interest_rate'].toString())
            : null,
        monthlyPayment: json['monthly_payment'] != null
            ? double.parse(json['monthly_payment'].toString())
            : null,
        remainingTermMonths: json['remaining_term_months'],
        loanType: json['loan_type'] != null
            ? LoanType.values.firstWhere((e) => e.name == json['loan_type'],
                orElse: () => LoanType.other)
            : null,
        lenderName: json['lender_name'],
        isActive: json['is_active'] ?? true,
        lastSyncedAt: json['last_synced_at'] != null
            ? DateTime.parse(json['last_synced_at'])
            : null,
      );

  @override
  List<Object?> get props => [id, accountType, currentBalance];
}

// ── Dashboard summary ─────────────────────────────────────────────────────────

class SpendingByCategory extends Equatable {
  final String? categoryId;
  final String categoryName;
  final String? categoryColor;
  final double total;
  final double pctOfTotal;
  final bool? isNeed;
  final int transactionCount;

  const SpendingByCategory({
    this.categoryId,
    required this.categoryName,
    this.categoryColor,
    required this.total,
    required this.pctOfTotal,
    this.isNeed,
    required this.transactionCount,
  });

  factory SpendingByCategory.fromJson(Map<String, dynamic> json) =>
      SpendingByCategory(
        categoryId: json['category_id'],
        categoryName: json['category_name'],
        categoryColor: json['category_color'],
        total: double.parse(json['total'].toString()),
        pctOfTotal: (json['pct_of_total'] ?? 0).toDouble(),
        isNeed: json['is_need'],
        transactionCount: json['transaction_count'] ?? 0,
      );

  @override
  List<Object?> get props => [categoryId, total];
}

class DashboardSummary extends Equatable {
  final String periodKey;
  final double totalIncome;
  final double totalSpent;
  final double totalSaved;
  final double savingsRatePct;
  final double needsTotal;
  final double wantsTotal;
  final double needsPct;
  final double wantsPct;
  final double? budgetAmount;
  final double? budgetPctUsed;
  final double? budgetRemaining;
  final int daysInPeriod;
  final int daysElapsed;
  final int daysRemaining;
  final double? projectedSpend;
  final List<SpendingByCategory> spendingByCategory;
  final String? topInsight;

  const DashboardSummary({
    required this.periodKey,
    required this.totalIncome,
    required this.totalSpent,
    required this.totalSaved,
    required this.savingsRatePct,
    required this.needsTotal,
    required this.wantsTotal,
    required this.needsPct,
    required this.wantsPct,
    this.budgetAmount,
    this.budgetPctUsed,
    this.budgetRemaining,
    required this.daysInPeriod,
    required this.daysElapsed,
    required this.daysRemaining,
    this.projectedSpend,
    required this.spendingByCategory,
    this.topInsight,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        periodKey: json['period_key'],
        totalIncome: double.parse(json['total_income'].toString()),
        totalSpent: double.parse(json['total_spent'].toString()),
        totalSaved: double.parse(json['total_saved'].toString()),
        savingsRatePct: (json['savings_rate_pct'] ?? 0).toDouble(),
        needsTotal: double.parse(json['needs_total'].toString()),
        wantsTotal: double.parse(json['wants_total'].toString()),
        needsPct: (json['needs_pct'] ?? 0).toDouble(),
        wantsPct: (json['wants_pct'] ?? 0).toDouble(),
        budgetAmount: json['budget_amount'] != null
            ? double.parse(json['budget_amount'].toString())
            : null,
        budgetPctUsed: json['budget_pct_used']?.toDouble(),
        budgetRemaining: json['budget_remaining'] != null
            ? double.parse(json['budget_remaining'].toString())
            : null,
        daysInPeriod: json['days_in_period'],
        daysElapsed: json['days_elapsed'],
        daysRemaining: json['days_remaining'],
        projectedSpend: json['projected_spend'] != null
            ? double.parse(json['projected_spend'].toString())
            : null,
        spendingByCategory:
            (json['spending_by_category'] as List<dynamic>? ?? [])
                .map((e) => SpendingByCategory.fromJson(e))
                .toList(),
        topInsight: json['top_insight'],
      );

  @override
  List<Object?> get props => [periodKey, totalSpent, totalIncome];
}

// ── Savings Goal ──────────────────────────────────────────────────────────────

class SavingsGoalModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String? linkedAccountId;
  final String? icon;
  final String? color;
  final GoalStatus status;
  final String? aiSuggestion;
  final DateTime createdAt;

  const SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.linkedAccountId,
    this.icon,
    this.color,
    required this.status,
    this.aiSuggestion,
    required this.createdAt,
  });

  double get progressPct =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;

  double get remaining =>
      (targetAmount - currentAmount).clamp(0, double.infinity);

  bool get isCompleted => currentAmount >= targetAmount;

  String? get projectedCompletionLabel {
    if (isCompleted) return 'Completed';
    if (targetDate != null) {
      final months = targetDate!.difference(DateTime.now()).inDays / 30;
      return months < 1 ? 'This month' : 'In ${months.round()} months';
    }
    return null;
  }

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) =>
      SavingsGoalModel(
        id: json['id'],
        userId: json['user_id'],
        name: json['name'],
        targetAmount: double.parse(json['target_amount'].toString()),
        currentAmount: double.parse(json['current_amount'].toString()),
        targetDate: json['target_date'] != null
            ? DateTime.parse(json['target_date'])
            : null,
        linkedAccountId: json['linked_account_id'],
        icon: json['icon'],
        color: json['color'],
        status: GoalStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => GoalStatus.active,
        ),
        aiSuggestion: json['ai_suggestion'],
        createdAt: DateTime.parse(json['created_at']),
      );

  @override
  List<Object?> get props => [id, targetAmount, currentAmount, status];
}

// ── Bill ──────────────────────────────────────────────────────────────────────

class BillModel extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double? amount;
  final int dueDay;
  final String? categoryId;
  final bool isAutopay;
  final bool isActive;
  final DateTime createdAt;

  const BillModel({
    required this.id,
    required this.userId,
    required this.name,
    this.amount,
    required this.dueDay,
    this.categoryId,
    required this.isAutopay,
    required this.isActive,
    required this.createdAt,
  });

  factory BillModel.fromJson(Map<String, dynamic> json) => BillModel(
        id: json['id'],
        userId: json['user_id'],
        name: json['name'],
        amount: json['amount'] != null
            ? double.parse(json['amount'].toString())
            : null,
        dueDay: json['due_day'],
        categoryId: json['category_id'],
        isAutopay: json['is_autopay'] ?? false,
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at']),
      );

  @override
  List<Object?> get props => [id, name, dueDay];
}

class BillPaymentModel extends Equatable {
  final String id;
  final String billId;
  final String userId;
  final double? amountPaid;
  final DateTime dueDate;
  final DateTime? paidDate;
  final BillStatus status;
  final String? transactionId;
  final BillModel? bill;

  const BillPaymentModel({
    required this.id,
    required this.billId,
    required this.userId,
    this.amountPaid,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.transactionId,
    this.bill,
  });

  bool get isPaid => status == BillStatus.paid;
  bool get isOverdue => status == BillStatus.overdue;

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  factory BillPaymentModel.fromJson(Map<String, dynamic> json) =>
      BillPaymentModel(
        id: json['id'],
        billId: json['bill_id'],
        userId: json['user_id'],
        amountPaid: json['amount_paid'] != null
            ? double.parse(json['amount_paid'].toString())
            : null,
        dueDate: DateTime.parse(json['due_date']),
        paidDate: json['paid_date'] != null
            ? DateTime.parse(json['paid_date'])
            : null,
        status: BillStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => BillStatus.unpaid,
        ),
        transactionId: json['transaction_id'],
        bill: json['bill'] != null ? BillModel.fromJson(json['bill']) : null,
      );

  @override
  List<Object?> get props => [id, billId, status, dueDate];
}

// ── Debt Plan ─────────────────────────────────────────────────────────────────

class DebtAllocation extends Equatable {
  final String accountId;
  final String accountName;
  final double balance;
  final double apr;
  final double minimumPayment;
  final double totalPayment;
  final DateTime projectedPayoffDate;
  final int payoffOrder;

  const DebtAllocation({
    required this.accountId,
    required this.accountName,
    required this.balance,
    required this.apr,
    required this.minimumPayment,
    required this.totalPayment,
    required this.projectedPayoffDate,
    required this.payoffOrder,
  });

  factory DebtAllocation.fromJson(Map<String, dynamic> json) => DebtAllocation(
        accountId: json['account_id'],
        accountName: json['account_name'],
        balance: double.parse(json['balance'].toString()),
        apr: double.parse(json['apr'].toString()),
        minimumPayment: double.parse(json['minimum_payment'].toString()),
        totalPayment: double.parse(json['total_payment'].toString()),
        projectedPayoffDate: DateTime.parse(json['projected_payoff_date']),
        payoffOrder: json['payoff_order'],
      );

  @override
  List<Object?> get props => [accountId, balance, payoffOrder];
}

class DebtPlanModel extends Equatable {
  final String id;
  final String userId;
  final DebtStrategy strategy;
  final double monthlyExtraPayment;
  final DateTime freedomDate;
  final double totalInterestSaved;
  final double totalInterestWithMinimums;
  final List<DebtAllocation> allocations;
  final String? aiNarrative;
  final DateTime generatedAt;

  const DebtPlanModel({
    required this.id,
    required this.userId,
    required this.strategy,
    required this.monthlyExtraPayment,
    required this.freedomDate,
    required this.totalInterestSaved,
    required this.totalInterestWithMinimums,
    required this.allocations,
    this.aiNarrative,
    required this.generatedAt,
  });

  String get freedomDateLabel {
    final months = freedomDate.difference(DateTime.now()).inDays ~/ 30;
    if (months <= 0) return 'This month!';
    if (months < 12) return 'In $months months';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem > 0 ? 'In $years yr ${rem}mo' : 'In $years years';
  }

  factory DebtPlanModel.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>;
    return DebtPlanModel(
      id: json['id'],
      userId: json['user_id'],
      strategy: DebtStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => DebtStrategy.avalanche,
      ),
      monthlyExtraPayment:
          double.parse(json['monthly_extra_payment'].toString()),
      freedomDate: DateTime.parse(content['freedom_date']),
      totalInterestSaved:
          double.parse(content['total_interest_saved'].toString()),
      totalInterestWithMinimums:
          double.parse(content['total_interest_with_minimums'].toString()),
      allocations: (content['allocations'] as List<dynamic>? ?? [])
          .map((e) => DebtAllocation.fromJson(e))
          .toList(),
      aiNarrative: content['narrative'],
      generatedAt: DateTime.parse(json['generated_at']),
    );
  }

  @override
  List<Object?> get props => [id, strategy, freedomDate, totalInterestSaved];
}

// ── Insight ───────────────────────────────────────────────────────────────────

class InsightItem extends Equatable {
  final String type;
  final String title;
  final String body;
  final String? actionLabel;
  final String? actionType;

  const InsightItem({
    required this.type,
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionType,
  });

  factory InsightItem.fromJson(Map<String, dynamic> json) => InsightItem(
        type: json['type'],
        title: json['title'],
        body: json['body'],
        actionLabel: json['action_label'],
        actionType: json['action_type'],
      );

  @override
  List<Object?> get props => [type, title];
}

class InsightModel extends Equatable {
  final String id;
  final String periodKey;
  final String summary;
  final List<InsightItem> insights;
  final List<InsightItem> recommendations;
  final bool? thumbsUp;
  final DateTime generatedAt;

  const InsightModel({
    required this.id,
    required this.periodKey,
    required this.summary,
    required this.insights,
    required this.recommendations,
    this.thumbsUp,
    required this.generatedAt,
  });

  factory InsightModel.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>;
    return InsightModel(
      id: json['id'],
      periodKey: json['period_key'],
      summary: content['summary'] ?? '',
      insights: (content['insights'] as List<dynamic>? ?? [])
          .map((e) => InsightItem.fromJson(e))
          .toList(),
      recommendations: (content['recommendations'] as List<dynamic>? ?? [])
          .map((e) => InsightItem.fromJson(e))
          .toList(),
      thumbsUp: json['thumbs_up'],
      generatedAt: DateTime.parse(json['generated_at']),
    );
  }

  @override
  List<Object?> get props => [id, periodKey];
}
