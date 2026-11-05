import 'dart:math' as math;
import 'package:mintflow_flutter/core/router/app_router.dart';
import 'package:mintflow_flutter/core/theme/app_theme.dart';
import 'package:mintflow_flutter/core/theme/breakpoints.dart';
import 'package:mintflow_flutter/core/theme/motion.dart';
import 'package:mintflow_flutter/core/utils/format.dart';
import 'package:mintflow_flutter/data/models/models.dart';
import 'package:mintflow_flutter/presentation/cubits/cubits.dart';
import 'package:mintflow_flutter/presentation/widgets/semantic_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _contentController;
  late Animation<double> _ringProgress;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  double _targetProgress = 0;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCubit>().load();
      context.read<UserCubit>().load();
      context.read<TransactionCubit>().load();
    });
  }

  void _animateFor(DashboardSummary summary) {
    final pct = ((summary.budgetPctUsed ?? 0) / 100).clamp(0.0, 1.0);
    _targetProgress = pct;
    if (!mounted) return;
    if (MintMotion.reduce(context)) {
      _ringController.value = 1;
      _contentController.value = 1;
      return;
    }
    _ringController.forward(from: 0);
    // Always restart content entrance (refresh used to leave controller at 1).
    _contentController.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ringController.duration = MintMotion.duration(
      context,
      const Duration(milliseconds: 1100),
    );
    _contentController.duration = MintMotion.duration(
      context,
      const Duration(milliseconds: 450),
    );
  }

  @override
  void dispose() {
    _ringController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.green900,
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listenWhen: (prev, next) => prev != next,
        buildWhen: (prev, next) => prev != next,
        listener: (context, state) {
          if (state is DashboardLoaded) _animateFor(state.summary);
        },
        builder: (context, dashState) {
          if (dashState is DashboardLoading || dashState is DashboardInitial) {
            return const Center(
              child: CircularProgressIndicator(color: MintflowColors.green400),
            );
          }
          if (dashState is DashboardError) {
            return _ErrorBody(
              message: dashState.message,
              onRetry: () => context.read<DashboardCubit>().refresh(),
            );
          }
          final summary = (dashState as DashboardLoaded).summary;
          return Column(
            children: [
              BlocBuilder<UserCubit, UserState>(
                buildWhen: (prev, next) => prev != next,
                builder: (context, userState) {
                  final name = userState is UserLoaded
                      ? userState.user.displayName
                      : 'there';
                  return _DashHeader(
                    greeting: _greeting(),
                    displayName: name,
                  );
                },
              ),
              _RingSection(
                progressAnim: _ringProgress,
                targetProgress: _targetProgress,
                spent: summary.totalSpent,
                budget: summary.budgetAmount,
                daysRemaining: summary.daysRemaining,
                remaining: summary.budgetRemaining,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: MintflowColors.page(context),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_contentFade, _contentSlide]),
                    // Child is built once — avoids rebuilding the feed every frame.
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      child: RefreshIndicator(
                        color: MintflowColors.green500,
                        onRefresh: () async {
                          await Future.wait([
                            context.read<DashboardCubit>().refresh(),
                            context.read<TransactionCubit>().load(),
                          ]);
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final expanded =
                                MintBreakpoints.isExpanded(context);
                            final feed = <Widget>[
                              _SummaryRow(summary: summary),
                              const SizedBox(height: 16),
                              const _SubscriptionsTeaser(),
                              const SizedBox(height: 8),
                              const _BillsTeaser(),
                              const SizedBox(height: 16),
                              _InsightCard(
                                insight: summary.topInsight,
                                categories: summary.spendingByCategory,
                                summary: summary,
                              ),
                            ];
                            final recent = const [
                              _RecentTransactions(),
                              SizedBox(height: 8),
                            ];
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                  20, 20, 20, 24),
                              child: expanded
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: feed,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: recent,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [...feed, ...recent],
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: MintflowTextStyles.bodyMedium
                    .copyWith(color: MintflowColors.cream)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DashHeader extends StatelessWidget {
  final String greeting;
  final String displayName;
  const _DashHeader({required this.greeting, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: MintflowColors.green900,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: MintflowTextStyles.bodySmall.copyWith(
                    color: MintflowColors.onBrandMuted(context, 0.5),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MintflowTextStyles.displaySmall.copyWith(
                    color: MintflowColors.cream,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Notifications',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(MintflowRoutes.notifications),
                child: Semantics(
                  button: true,
                  label: 'Notifications',
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MintflowColors.green600,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: MintflowColors.onBrand(context),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ring ──────────────────────────────────────────────────────────────────────

class _RingSection extends StatelessWidget {
  final Animation<double> progressAnim;
  final double targetProgress;
  final double spent;
  final double? budget;
  final double? remaining;
  final int daysRemaining;

  const _RingSection({
    required this.progressAnim,
    required this.targetProgress,
    required this.spent,
    required this.budget,
    required this.remaining,
    required this.daysRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final remLabel = remaining != null
        ? 'Left ${MintflowFormat.currencyCompact(remaining!)}'
        : 'Left';
    final budgetLabel = budget != null
        ? 'of ${MintflowFormat.currencyCompact(budget!)}'
        : 'spent this month';
    final pctLabel = ((targetProgress * 100).round()).clamp(0, 999);

    return Container(
      color: MintflowColors.green900,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: progressAnim,
            child: Text(
              budgetLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: MintflowTextStyles.labelSmall.copyWith(
                color: MintflowColors.onBrandMuted(context, 0.45),
                fontWeight: FontWeight.w300,
              ),
            ),
            builder: (_, labelChild) {
              final t = progressAnim.value;
              final p = t * targetProgress;
              return SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _BudgetRingPainter(progress: p),
                  isComplex: true,
                  willChange: true,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              MintflowFormat.currency(spent * t),
                              maxLines: 1,
                              style: MintflowTextStyles.amountMedium.copyWith(
                                color: MintflowColors.cream,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          labelChild!,
                          const SizedBox(height: 4),
                          Text(
                            '${(pctLabel * t).round()}% used',
                            style: MintflowTextStyles.labelMedium.copyWith(
                              color: MintflowColors.green400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                const Expanded(
                  child: _RingLegendItem(
                    color: MintflowColors.green400,
                    label: 'Spent',
                  ),
                ),
                Expanded(
                  child: _RingLegendItem(
                    color: MintflowColors.brandOverlay(context, 0.15),
                    label: remLabel,
                  ),
                ),
                Expanded(
                  child: _RingLegendItem(
                    color: MintflowColors.gold400,
                    label: '$daysRemaining days left',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _RingLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: MintflowTextStyles.labelSmall.copyWith(
              color: MintflowColors.onBrandMuted(context, 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetRingPainter extends CustomPainter {
  final double progress;
  _BudgetRingPainter({required this.progress});

  static final _trackPaint = Paint()
    ..color = MintflowColors.cream.withValues(alpha: 0.08)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round;

  static final _progressPaint = Paint()
    ..color = MintflowColors.green400
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round;

  static final _tipFill = Paint()..color = MintflowColors.gold400;
  static final _tipStroke = Paint()
    ..color = MintflowColors.green900
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const startAngle = -math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, _trackPaint);

    if (progress > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        2 * math.pi * progress,
        false,
        _progressPaint,
      );

      final tipAngle = startAngle + (2 * math.pi * progress);
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(tip, 5, _tipFill);
      canvas.drawCircle(tip, 5, _tipStroke);
    }
  }

  @override
  bool shouldRepaint(_BudgetRingPainter old) =>
      (old.progress - progress).abs() > 0.002;
}

// ── Summary ───────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final DashboardSummary summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Income',
            value: MintflowFormat.currencyCompact(summary.totalIncome),
            change: 'this month',
            isNegative: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Saved',
            value: MintflowFormat.currencyCompact(summary.totalSaved),
            change:
                '${MintflowFormat.percentage(summary.savingsRatePct)} rate',
            isNegative: summary.totalSaved < 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Needs',
            value: MintflowFormat.percentage(summary.needsPct),
            change:
                '${MintflowFormat.percentage(summary.wantsPct)} wants',
            isNegative: summary.needsPct > 70,
          ),
        ),
      ],
    );
  }
}

class _SubscriptionsTeaser extends StatelessWidget {
  const _SubscriptionsTeaser();

  @override
  Widget build(BuildContext context) {
    return SemanticTap(
      label: 'Subscriptions',
      onTap: () => context.push(MintflowRoutes.recurringSubscriptions),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MintflowColors.card(context),
          borderRadius: MintflowRadius.xl_,
          border: Border.all(color: MintflowColors.hairline(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MintflowColors.purpleWash(context),
                borderRadius: MintflowRadius.md_,
              ),
              child: const Icon(Icons.subscriptions_outlined,
                  color: MintflowColors.purple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subscriptions', style: MintflowTextStyles.labelMedium),
                  Text(
                    'Auto-detected from your banks',
                    style: MintflowTextStyles.overline
                        .copyWith(color: MintflowColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.textTertiary(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _BillsTeaser extends StatelessWidget {
  const _BillsTeaser();

  @override
  Widget build(BuildContext context) {
    return SemanticTap(
      label: 'Bills',
      onTap: () => context.push(MintflowRoutes.bills),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MintflowColors.card(context),
          borderRadius: MintflowRadius.xl_,
          border: Border.all(color: MintflowColors.hairline(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MintflowColors.blueWash(context),
                borderRadius: MintflowRadius.md_,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: MintflowColors.blue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bills', style: MintflowTextStyles.labelMedium),
                  Text(
                    'Rent, utilities, due dates',
                    style: MintflowTextStyles.overline
                        .copyWith(color: MintflowColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.textTertiary(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value, change;
  final bool isNegative;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.change,
    required this.isNegative,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        borderRadius: MintflowRadius.lg_,
        border: Border.all(color: MintflowColors.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: MintflowTextStyles.overline.copyWith(
              color: MintflowColors.textSecondary(context),
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MintflowTextStyles.amountSmall.copyWith(
              color: MintflowColors.textPrimary(context),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            change,
            style: MintflowTextStyles.labelSmall.copyWith(
              color: isNegative ? MintflowColors.red : MintflowColors.green500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insight ───────────────────────────────────────────────────────────────────

class _InsightCard extends StatefulWidget {
  final String? insight;
  final List<SpendingByCategory> categories;
  final DashboardSummary summary;
  const _InsightCard({
    required this.insight,
    required this.categories,
    required this.summary,
  });

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.insight?.trim();
    if (_dismissed || text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: MintflowColors.green900,
        borderRadius: MintflowRadius.xl_,
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: MintflowColors.gold400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'FLOWRA INSIGHT',
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.gold400,
                    letterSpacing: 0.08,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: MintflowTextStyles.bodySmall.copyWith(
                color: MintflowColors.onBrandMuted(context, 0.85),
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SemanticTap(
                  label: 'See breakdown',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DashboardBreakdownScreen(
                        summary: widget.summary,
                      ),
                    ),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MintflowColors.green400,
                      borderRadius: MintflowRadius.sm_,
                    ),
                    child: Text(
                      'See breakdown',
                      style: MintflowTextStyles.labelSmall.copyWith(
                        color: MintflowColors.onMint(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SemanticTap(
                  label: 'Dismiss insight',
                  onTap: () => setState(() => _dismissed = true),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MintflowColors.brandOverlay(context, 0.1),
                      borderRadius: MintflowRadius.sm_,
                    ),
                    child: Text(
                      'Dismiss',
                      style: MintflowTextStyles.labelSmall.copyWith(
                        color: MintflowColors.onBrandMuted(context, 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent transactions ───────────────────────────────────────────────────────

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionCubit, TransactionState>(
      buildWhen: (prev, next) => prev != next,
      builder: (context, state) {
        final items = state is TransactionLoaded
            ? state.items.take(5).toList()
            : <TransactionModel>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent',
                  style: MintflowTextStyles.labelLarge.copyWith(
                    color: MintflowColors.textPrimary(context),
                  ),
                ),
                SemanticTap(
                  label: 'See all transactions',
                  onTap: () => context.go(MintflowRoutes.transactions),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    child: Text(
                      'See all',
                      style: MintflowTextStyles.labelMedium.copyWith(
                        color: MintflowColors.green600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (state is TransactionLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No transactions yet. Tap + to add one.',
                  style: MintflowTextStyles.bodySmall
                      .copyWith(color: MintflowColors.textSecondary(context)),
                ),
              )
            else
              ...List.generate(items.length, (i) {
                final tx = items[i];
                return _TransactionItem(
                  key: ValueKey(tx.id),
                  tx: tx,
                  isLast: i == items.length - 1,
                );
              }),
          ],
        );
      },
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionModel tx;
  final bool isLast;
  const _TransactionItem({
    super.key,
    required this.tx,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final tag = tx.isNeed == null ? null : (tx.isNeed! ? 'need' : 'want');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: MintflowColors.hairline(context), width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tx.isIncome
                  ? MintflowColors.mintWash(context)
                  : MintflowColors.softFill(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tx.isIncome
                  ? Icons.trending_up
                  : Icons.receipt_long_outlined,
              color: tx.isIncome
                  ? MintflowColors.green500
                  : MintflowColors.textSecondary(context),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tx.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: MintflowTextStyles.labelMedium.copyWith(
                          color: MintflowColors.textPrimary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 6),
                      _TxTag(tag: tag),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    MintflowFormat.relativeDate(tx.date),
                    if (tx.category?.name != null) tx.category!.name,
                  ].join(' · '),
                  style: MintflowTextStyles.labelSmall.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            tx.isIncome
                ? '+${MintflowFormat.currency(tx.amount)}'
                : '-${MintflowFormat.currency(tx.amount)}',
            style: MintflowTextStyles.labelLarge.copyWith(
              color: tx.isIncome
                  ? MintflowColors.green400
                  : MintflowColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxTag extends StatelessWidget {
  final String tag;
  const _TxTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    final isNeed = tag == 'need';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isNeed
            ? MintflowColors.mintWash(context)
            : MintflowColors.wantWash(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: MintflowTextStyles.overline.copyWith(
          color: isNeed ? MintflowColors.green600 : MintflowColors.wantLabel(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Breakdown ─────────────────────────────────────────────────────────────────

class DashboardBreakdownScreen extends StatelessWidget {
  final DashboardSummary? summary;
  const DashboardBreakdownScreen({super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    final cats = summary?.spendingByCategory ?? [];
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: MintflowColors.softFill(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        minimumSize: const Size(48, 48),
                      ),
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: MintflowColors.textSecondary(context),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    summary != null
                        ? MintflowFormat.monthYear(DateTime.now())
                        : 'Breakdown',
                    style: MintflowTextStyles.displaySmall.copyWith(
                      color: MintflowColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (summary != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MintflowColors.card(context),
                          borderRadius: MintflowRadius.xl_,
                          border: Border.all(color: MintflowColors.hairline(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Needs ${MintflowFormat.percentage(summary!.needsPct)}',
                                style: MintflowTextStyles.labelLarge,
                              ),
                            ),
                            Text(
                              'Wants ${MintflowFormat.percentage(summary!.wantsPct)}',
                              style: MintflowTextStyles.labelLarge
                                  .copyWith(color: MintflowColors.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Spending by category',
                      style: MintflowTextStyles.labelLarge
                          .copyWith(color: MintflowColors.textPrimary(context)),
                    ),
                    const SizedBox(height: 10),
                    if (cats.isEmpty)
                      Text(
                        'No category spend yet. Add or sync transactions to see a breakdown.',
                        style: MintflowTextStyles.bodySmall
                            .copyWith(color: MintflowColors.textSecondary(context)),
                      )
                    else
                      ...cats.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.categoryName,
                                    style: MintflowTextStyles.bodySmall,
                                  ),
                                ),
                                Text(
                                  MintflowFormat.currency(c.total),
                                  style: MintflowTextStyles.labelMedium,
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
