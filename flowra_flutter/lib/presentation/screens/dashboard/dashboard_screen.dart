import 'dart:math' as math;
import 'package:flowra_flutter/core/router/app_router.dart';
import 'package:flowra_flutter/core/theme/app_theme.dart';
import 'package:flowra_flutter/core/utils/format.dart';
import 'package:flowra_flutter/data/models/models.dart';
import 'package:flowra_flutter/presentation/cubits/cubits.dart';
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
    _ringController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _contentController.forward();
    });
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
      backgroundColor: FlowraColors.green900,
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state is DashboardLoaded) _animateFor(state.summary);
        },
        builder: (context, dashState) {
          if (dashState is DashboardLoading || dashState is DashboardInitial) {
            return const Center(
              child: CircularProgressIndicator(color: FlowraColors.green400),
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
                  decoration: const BoxDecoration(
                    color: FlowraColors.cream,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        child: RefreshIndicator(
                          color: FlowraColors.green500,
                          onRefresh: () async {
                            await Future.wait([
                              context.read<DashboardCubit>().refresh(),
                              context.read<TransactionCubit>().load(),
                            ]);
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding:
                                const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SummaryRow(summary: summary),
                                const SizedBox(height: 14),
                                _InsightCard(
                                  insight: summary.topInsight,
                                  categories: summary.spendingByCategory,
                                  summary: summary,
                                ),
                                const SizedBox(height: 14),
                                const _RecentTransactions(),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
                style: FlowraTextStyles.bodyMedium
                    .copyWith(color: FlowraColors.cream)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
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
      color: FlowraColors.green900,
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: FlowraTextStyles.bodySmall.copyWith(
                  color: FlowraColors.cream.withOpacity(0.5),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                style: FlowraTextStyles.displaySmall.copyWith(
                  color: FlowraColors.cream,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FlowraColors.green600,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 20,
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
    final budgetLabel = budget != null
        ? 'of ${FlowraFormat.currency(budget!)} spent'
        : 'spent this month';
    final pctLabel = ((targetProgress * 100).round()).clamp(0, 999);
    final remLabel = remaining != null
        ? 'Remaining ${FlowraFormat.currency(remaining!)}'
        : 'Remaining';

    return Container(
      color: FlowraColors.green900,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: progressAnim,
            builder: (_, __) {
              final p = progressAnim.value * targetProgress;
              return SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _BudgetRingPainter(progress: p),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          FlowraFormat.currency(spent * progressAnim.value),
                          style: FlowraTextStyles.amountMedium.copyWith(
                            color: FlowraColors.cream,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          budgetLabel,
                          style: FlowraTextStyles.labelSmall.copyWith(
                            color: FlowraColors.cream.withOpacity(0.45),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(pctLabel * progressAnim.value).round()}% used',
                          style: FlowraTextStyles.labelMedium.copyWith(
                            color: FlowraColors.green400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _RingLegendItem(
                  color: FlowraColors.green400,
                  label: 'Spent',
                ),
                const SizedBox(width: 20),
                _RingLegendItem(
                  color: Colors.white.withOpacity(0.15),
                  label: remLabel,
                ),
                const SizedBox(width: 20),
                _RingLegendItem(
                  color: FlowraColors.gold400,
                  label: '$daysRemaining days left',
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
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: FlowraTextStyles.labelSmall.copyWith(
            color: FlowraColors.cream.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}

class _BudgetRingPainter extends CustomPainter {
  final double progress;
  _BudgetRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + (2 * math.pi * progress),
          colors: const [Color(0xFF2EAD6A), Color(0xFF1D9256)],
          tileMode: TileMode.clamp,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * progress,
        false,
        progressPaint,
      );

      final tipAngle = startAngle + (2 * math.pi * progress);
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(tip, 5, Paint()..color = const Color(0xFFEDB93A));
      canvas.drawCircle(
        tip,
        5,
        Paint()
          ..color = const Color(0xFF0A2E1C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BudgetRingPainter old) => old.progress != progress;
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
            value: FlowraFormat.currencyCompact(summary.totalIncome),
            change: 'this month',
            isNegative: false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Saved',
            value: FlowraFormat.currencyCompact(summary.totalSaved),
            change:
                '${FlowraFormat.percentage(summary.savingsRatePct)} rate',
            isNegative: summary.totalSaved < 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Needs',
            value: FlowraFormat.percentage(summary.needsPct),
            change:
                '${FlowraFormat.percentage(summary.wantsPct)} wants',
            isNegative: summary.needsPct > 70,
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FlowraRadius.lg_,
        border: Border.all(color: FlowraColors.creamDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: FlowraTextStyles.overline.copyWith(
              color: FlowraColors.ink60,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: FlowraTextStyles.amountSmall.copyWith(
              color: FlowraColors.ink,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            change,
            style: FlowraTextStyles.labelSmall.copyWith(
              color: isNegative ? FlowraColors.red : FlowraColors.green500,
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
        color: FlowraColors.green900,
        borderRadius: FlowraRadius.xl_,
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
                    color: FlowraColors.gold400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'FLOWRA INSIGHT',
                  style: FlowraTextStyles.overline.copyWith(
                    color: FlowraColors.gold400,
                    letterSpacing: 0.08,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: FlowraTextStyles.bodySmall.copyWith(
                color: FlowraColors.cream.withOpacity(0.85),
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DashboardBreakdownScreen(
                        summary: widget.summary,
                      ),
                    ),
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: FlowraColors.green400,
                      borderRadius: FlowraRadius.sm_,
                    ),
                    child: Text(
                      'See breakdown',
                      style: FlowraTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: FlowraRadius.sm_,
                    ),
                    child: Text(
                      'Dismiss',
                      style: FlowraTextStyles.labelSmall.copyWith(
                        color: FlowraColors.cream.withOpacity(0.65),
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
                  style: FlowraTextStyles.labelLarge.copyWith(
                    color: FlowraColors.ink,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(FlowraRoutes.transactions),
                  child: Text(
                    'See all',
                    style: FlowraTextStyles.labelMedium.copyWith(
                      color: FlowraColors.green500,
                      fontWeight: FontWeight.w500,
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
                  style: FlowraTextStyles.bodySmall
                      .copyWith(color: FlowraColors.ink60),
                ),
              )
            else
              ...List.generate(items.length, (i) {
                final tx = items[i];
                return _TransactionItem(
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
  const _TransactionItem({required this.tx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final tag = tx.isNeed == null ? null : (tx.isNeed! ? 'need' : 'want');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: FlowraColors.ink10, width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tx.isIncome
                  ? FlowraColors.green50
                  : FlowraColors.creamDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              tx.isIncome
                  ? Icons.trending_up
                  : Icons.receipt_long_outlined,
              color: tx.isIncome
                  ? FlowraColors.green500
                  : FlowraColors.ink60,
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
                        style: FlowraTextStyles.labelMedium.copyWith(
                          color: FlowraColors.ink,
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
                    FlowraFormat.relativeDate(tx.date),
                    if (tx.category?.name != null) tx.category!.name,
                  ].join(' · '),
                  style: FlowraTextStyles.labelSmall.copyWith(
                    color: FlowraColors.ink60,
                  ),
                ),
              ],
            ),
          ),
          Text(
            tx.isIncome
                ? '+${FlowraFormat.currency(tx.amount)}'
                : '-${FlowraFormat.currency(tx.amount)}',
            style: FlowraTextStyles.labelLarge.copyWith(
              color: tx.isIncome ? FlowraColors.green400 : FlowraColors.ink,
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
        color: isNeed ? FlowraColors.green50 : const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        tag,
        style: FlowraTextStyles.overline.copyWith(
          color: isNeed ? FlowraColors.green600 : const Color(0xFF9A6200),
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
      backgroundColor: FlowraColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: FlowraColors.creamDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: FlowraColors.ink60,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    summary != null
                        ? FlowraFormat.monthYear(DateTime.now())
                        : 'Breakdown',
                    style: FlowraTextStyles.displaySmall.copyWith(
                      color: FlowraColors.ink,
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
                          color: Colors.white,
                          borderRadius: FlowraRadius.xl_,
                          border: Border.all(color: FlowraColors.ink10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Needs ${FlowraFormat.percentage(summary!.needsPct)}',
                                style: FlowraTextStyles.labelLarge,
                              ),
                            ),
                            Text(
                              'Wants ${FlowraFormat.percentage(summary!.wantsPct)}',
                              style: FlowraTextStyles.labelLarge
                                  .copyWith(color: FlowraColors.ink60),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'Spending by category',
                      style: FlowraTextStyles.labelLarge
                          .copyWith(color: FlowraColors.ink),
                    ),
                    const SizedBox(height: 10),
                    if (cats.isEmpty)
                      Text(
                        'No category spend yet.',
                        style: FlowraTextStyles.bodySmall
                            .copyWith(color: FlowraColors.ink60),
                      )
                    else
                      ...cats.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.categoryName,
                                    style: FlowraTextStyles.bodySmall,
                                  ),
                                ),
                                Text(
                                  FlowraFormat.currency(c.total),
                                  style: FlowraTextStyles.labelMedium,
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
