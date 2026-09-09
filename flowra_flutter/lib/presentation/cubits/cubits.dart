import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/repositories.dart';
import '../../data/models/models.dart';
import '../../data/datasources/service_locator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow Cubits — one per domain area.
// Pattern: state sealed class (loading / loaded / error) + Cubit.
// Screens call cubit methods; UI reacts to BlocBuilder.
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════
// Dashboard
// ═══════════════════════════════════════════════════════════════════════════

abstract class DashboardState extends Equatable {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
  @override
  List get props => [];
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
  @override
  List get props => [];
}

class DashboardLoaded extends DashboardState {
  final DashboardSummary summary;
  const DashboardLoaded(this.summary);
  @override
  List get props => [summary];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List get props => [message];
}

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repo;
  DashboardCubit()
      : _repo = ServiceLocator.instance.dashboard,
        super(const DashboardInitial());

  Future<void> load({int? year, int? month, bool forceRefresh = false}) async {
    emit(const DashboardLoading());
    try {
      final summary = await _repo.getSummary(
          year: year, month: month, forceRefresh: forceRefresh);
      emit(DashboardLoaded(summary));
    } catch (e) {
      emit(DashboardError(_msg(e)));
    }
  }

  Future<void> refresh() => load(forceRefresh: true);
}

// ═══════════════════════════════════════════════════════════════════════════
// Transactions
// ═══════════════════════════════════════════════════════════════════════════

abstract class TransactionState extends Equatable {
  const TransactionState();
}

class TransactionInitial extends TransactionState {
  const TransactionInitial();
  @override
  List get props => [];
}

class TransactionLoading extends TransactionState {
  final bool isPaginating;
  const TransactionLoading({this.isPaginating = false});
  @override
  List get props => [isPaginating];
}

class TransactionLoaded extends TransactionState {
  final List<TransactionModel> items;
  final bool hasMore;
  final int currentPage;
  final String filter;
  const TransactionLoaded({
    required this.items,
    required this.hasMore,
    required this.currentPage,
    required this.filter,
  });
  @override
  List get props => [items, hasMore, currentPage, filter];
}

class TransactionError extends TransactionState {
  final String message;
  const TransactionError(this.message);
  @override
  List get props => [message];
}

class TransactionSaving extends TransactionState {
  const TransactionSaving();
  @override
  List get props => [];
}

class TransactionSaved extends TransactionState {
  final TransactionModel transaction;
  const TransactionSaved(this.transaction);
  @override
  List get props => [transaction];
}

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository _repo;
  String _filter = 'all';
  String? _search;

  TransactionCubit()
      : _repo = ServiceLocator.instance.transactions,
        super(const TransactionInitial());

  Future<void> load({String filter = 'all', String? search}) async {
    _filter = filter;
    _search = search;
    emit(const TransactionLoading());
    try {
      final result =
          await _repo.getTransactions(filter: filter, search: search, page: 1);
      emit(TransactionLoaded(
        items: result.items,
        hasMore: result.hasMore,
        currentPage: 1,
        filter: filter,
      ));
    } catch (e) {
      emit(TransactionError(_msg(e)));
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! TransactionLoaded || !current.hasMore) return;
    emit(TransactionLoading(isPaginating: true));
    try {
      final result = await _repo.getTransactions(
        filter: _filter,
        search: _search,
        page: current.currentPage + 1,
      );
      emit(TransactionLoaded(
        items: [...current.items, ...result.items],
        hasMore: result.hasMore,
        currentPage: current.currentPage + 1,
        filter: _filter,
      ));
    } catch (e) {
      emit(current); // restore previous state on pagination error
    }
  }

  Future<void> applyFilter(String filter) =>
      load(filter: filter, search: _search);
  Future<void> search(String query) =>
      load(filter: _filter, search: query.isEmpty ? null : query);

  Future<void> createTransaction({
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
    emit(const TransactionSaving());
    try {
      final tx = await _repo.createTransaction(
        amount: amount,
        transactionType: transactionType,
        date: date,
        merchantName: merchantName,
        description: description,
        categoryId: categoryId,
        accountId: accountId,
        isNeed: isNeed,
        notes: notes,
        incomeSource: incomeSource,
      );
      emit(TransactionSaved(tx));
      // Reload to show new transaction at top
      await load(filter: _filter);
    } catch (e) {
      emit(TransactionError(_msg(e)));
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repo.deleteTransaction(id);
      await load(filter: _filter);
    } catch (e) {
      emit(TransactionError(_msg(e)));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Goals
// ═══════════════════════════════════════════════════════════════════════════

abstract class GoalState extends Equatable {
  const GoalState();
}

class GoalInitial extends GoalState {
  const GoalInitial();
  @override
  List get props => [];
}

class GoalLoading extends GoalState {
  const GoalLoading();
  @override
  List get props => [];
}

class GoalLoaded extends GoalState {
  final List<SavingsGoalModel> goals;
  const GoalLoaded(this.goals);
  @override
  List get props => [goals];
}

class GoalError extends GoalState {
  final String message;
  const GoalError(this.message);
  @override
  List get props => [message];
}

class GoalSaving extends GoalState {
  const GoalSaving();
  @override
  List get props => [];
}

class GoalCubit extends Cubit<GoalState> {
  final GoalRepository _repo;
  GoalCubit()
      : _repo = ServiceLocator.instance.goals,
        super(const GoalInitial());

  Future<void> load({bool forceRefresh = false}) async {
    emit(const GoalLoading());
    try {
      final goals = await _repo.getGoals(forceRefresh: forceRefresh);
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(_msg(e)));
    }
  }

  Future<void> create({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? icon,
    String? color,
  }) async {
    emit(const GoalSaving());
    try {
      await _repo.createGoal(
        name: name,
        targetAmount: targetAmount,
        targetDate: targetDate,
        icon: icon,
        color: color,
      );
      await load(forceRefresh: true);
    } catch (e) {
      emit(GoalError(_msg(e)));
    }
  }

  Future<void> contribute(String id, double amount) async {
    try {
      await _repo.contribute(id, amount);
      await load(forceRefresh: true);
    } catch (e) {
      emit(GoalError(_msg(e)));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.deleteGoal(id);
      await load(forceRefresh: true);
    } catch (e) {
      emit(GoalError(_msg(e)));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bills
// ═══════════════════════════════════════════════════════════════════════════

abstract class BillState extends Equatable {
  const BillState();
}

class BillInitial extends BillState {
  const BillInitial();
  @override
  List get props => [];
}

class BillLoading extends BillState {
  const BillLoading();
  @override
  List get props => [];
}

class BillLoaded extends BillState {
  final List<BillModel> bills;
  final List<BillPaymentModel> payments;
  const BillLoaded({required this.bills, required this.payments});
  @override
  List get props => [bills, payments];

  // Convenience: merge bill + payment status for current month
  List<BillWithStatus> get billsWithStatus {
    final now = DateTime.now();
    return bills.map((bill) {
      final dueDate = DateTime(now.year, now.month, bill.dueDay);
      final payment = payments.where((p) => p.billId == bill.id).firstOrNull;
      BillStatus status;
      if (payment?.isPaid == true) {
        status = BillStatus.paid;
      } else if (dueDate.isBefore(DateTime.now())) {
        status = BillStatus.overdue;
      } else {
        status = BillStatus.unpaid;
      }
      return BillWithStatus(
        bill: bill,
        payment: payment,
        status: status,
        dueDate: dueDate,
        daysUntilDue: dueDate.difference(DateTime.now()).inDays,
      );
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  double get totalMonthly => bills.fold(0, (s, b) => s + (b.amount ?? 0));
  int get paidCount =>
      billsWithStatus.where((b) => b.status == BillStatus.paid).length;
  int get overdueCount =>
      billsWithStatus.where((b) => b.status == BillStatus.overdue).length;
}

class BillError extends BillState {
  final String message;
  const BillError(this.message);
  @override
  List get props => [message];
}

class BillWithStatus {
  final BillModel bill;
  final BillPaymentModel? payment;
  final BillStatus status;
  final DateTime dueDate;
  final int daysUntilDue;
  const BillWithStatus({
    required this.bill,
    this.payment,
    required this.status,
    required this.dueDate,
    required this.daysUntilDue,
  });
}

class BillCubit extends Cubit<BillState> {
  final BillRepository _repo;
  BillCubit()
      : _repo = ServiceLocator.instance.bills,
        super(const BillInitial());

  Future<void> load({bool forceRefresh = false}) async {
    emit(const BillLoading());
    try {
      final results = await Future.wait([
        _repo.getBills(forceRefresh: forceRefresh),
        _repo.getPayments(),
      ]);
      emit(BillLoaded(
        bills: results[0] as List<BillModel>,
        payments: results[1] as List<BillPaymentModel>,
      ));
    } catch (e) {
      emit(BillError(_msg(e)));
    }
  }

  Future<void> create({
    required String name,
    double? amount,
    required int dueDay,
    bool isAutopay = false,
  }) async {
    try {
      await _repo.createBill(
        name: name,
        amount: amount,
        dueDay: dueDay,
        isAutopay: isAutopay,
      );
      await load(forceRefresh: true);
    } catch (e) {
      emit(BillError(_msg(e)));
    }
  }

  Future<void> markPaid(String billId, {double? amountPaid}) async {
    try {
      await _repo.markPaid(billId, amountPaid: amountPaid);
      await load(forceRefresh: true);
    } catch (e) {
      emit(BillError(_msg(e)));
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.deleteBill(id);
      await load(forceRefresh: true);
    } catch (e) {
      emit(BillError(_msg(e)));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Insights
// ═══════════════════════════════════════════════════════════════════════════

abstract class InsightState extends Equatable {
  const InsightState();
}

class InsightInitial extends InsightState {
  const InsightInitial();
  @override
  List get props => [];
}

class InsightLoading extends InsightState {
  const InsightLoading();
  @override
  List get props => [];
}

class InsightLoaded extends InsightState {
  final InsightModel insight;
  const InsightLoaded(this.insight);
  @override
  List get props => [insight];
}

class InsightError extends InsightState {
  final String message;
  const InsightError(this.message);
  @override
  List get props => [message];
}

class InsightUpgradeRequired extends InsightState {
  const InsightUpgradeRequired();
  @override
  List get props => [];
}

class InsightCubit extends Cubit<InsightState> {
  final InsightRepository _repo;
  InsightCubit()
      : _repo = ServiceLocator.instance.insights,
        super(const InsightInitial());

  /// Skip the API when the client already knows this tier cannot fetch insights.
  void requireUpgrade() => emit(const InsightUpgradeRequired());

  Future<void> load({int? year, int? month}) async {
    final now = DateTime.now();
    emit(const InsightLoading());
    try {
      final insight = await _repo.getMonthlyInsight(
        year: year ?? now.year,
        month: month ?? now.month,
      );
      emit(InsightLoaded(insight));
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        emit(const InsightUpgradeRequired());
        return;
      }
      emit(InsightError(_friendlyInsightError(e)));
    } catch (e) {
      emit(InsightError(_msg(e)));
    }
  }

  Future<void> submitFeedback(bool thumbsUp) async {
    final current = state;
    if (current is! InsightLoaded) return;
    try {
      final now = DateTime.now();
      await _repo.submitFeedback(now.year, now.month, thumbsUp);
      // Optimistically update the UI
      final updated = _cloneWithFeedback(current.insight, thumbsUp);
      emit(InsightLoaded(updated));
    } catch (_) {}
  }

  InsightModel _cloneWithFeedback(InsightModel m, bool thumbsUp) =>
      InsightModel(
        id: m.id,
        periodKey: m.periodKey,
        summary: m.summary,
        insights: m.insights,
        recommendations: m.recommendations,
        thumbsUp: thumbsUp,
        generatedAt: m.generatedAt,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// User / Profile
// ═══════════════════════════════════════════════════════════════════════════

abstract class UserState extends Equatable {
  const UserState();
}

class UserInitial extends UserState {
  const UserInitial();
  @override
  List get props => [];
}

class UserLoading extends UserState {
  const UserLoading();
  @override
  List get props => [];
}

class UserLoaded extends UserState {
  final UserModel user;
  const UserLoaded(this.user);
  @override
  List get props => [user];
}

class UserError extends UserState {
  final String message;
  const UserError(this.message);
  @override
  List get props => [message];
}

class UserCubit extends Cubit<UserState> {
  final UserRepository _repo;
  UserCubit()
      : _repo = ServiceLocator.instance.users,
        super(const UserInitial());

  Future<void> load({bool forceRefresh = false}) async {
    emit(const UserLoading());
    try {
      final user = await _repo.getMe(forceRefresh: forceRefresh);
      emit(UserLoaded(user));
    } catch (e) {
      emit(UserError(_msg(e)));
    }
  }

  Future<void> updateFirebaseToken(String token) async {
    try {
      await _repo.updateMe({'firebase_token': token});
    } catch (_) {}
  }

  Future<UserModel?> completeOnboarding(Map<String, dynamic> data) async {
    emit(const UserLoading());
    try {
      final user = await _repo.completeOnboarding(data);
      emit(UserLoaded(user));
      return user;
    } catch (e) {
      emit(UserError(_msg(e)));
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _repo.deleteAccount();
      emit(const UserInitial());
      return true;
    } catch (e) {
      emit(UserError(_msg(e)));
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper — extract a readable message from any error
// ─────────────────────────────────────────────────────────────────────────────

String _msg(Object e) {
  if (e is DioException) return _friendlyInsightError(e);
  if (e is Exception) {
    final s = e.toString();
    if (s.contains('DioException')) {
      return 'Something went wrong. Please try again.';
    }
    if (s.contains('message:')) {
      return s.split('message:').last.trim();
    }
    return s.replaceFirst('Exception: ', '');
  }
  return e.toString();
}

String _friendlyInsightError(DioException e) {
  final status = e.response?.statusCode;
  if (status != null && status >= 500) {
    return 'Could not load insights right now. Please try again.';
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return 'Check your connection and try again.';
  }
  return 'Could not load insights. Please try again.';
}
