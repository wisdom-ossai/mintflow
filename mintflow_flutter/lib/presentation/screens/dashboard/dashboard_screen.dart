import 'dart:math' as math;
import 'package:mintflow_flutter/core/router/app_router.dart';
import 'package:mintflow_flutter/core/theme/app_theme.dart';
import 'package:mintflow_flutter/core/theme/breakpoints.dart';
import 'package:mintflow_flutter/core/theme/motion.dart';
import 'package:mintflow_flutter/core/utils/format.dart';
import 'package:mintflow_flutter/core/utils/auth_errors.dart';
import 'package:mintflow_flutter/data/datasources/local_cache.dart';
import 'package:mintflow_flutter/data/datasources/service_locator.dart';
import 'package:mintflow_flutter/data/models/models.dart';
import 'package:mintflow_flutter/presentation/cubits/cubits.dart';
import 'package:mintflow_flutter/presentation/widgets/amount_edit_sheet.dart';
import 'package:mintflow_flutter/presentation/widgets/empty_state.dart';
import 'package:mintflow_flutter/presentation/widgets/error_state.dart';
import 'package:mintflow_flutter/presentation/widgets/mint_card.dart';
import 'package:mintflow_flutter/presentation/widgets/mint_skeleton.dart';
import 'package:mintflow_flutter/presentation/widgets/semantic_tap.dart';
import 'package:mintflow_flutter/presentation/widgets/upgrade_soft_gate.dart';
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
      context.read<BillCubit>().load();
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

  Future<void> _editMonthlyBudget(double? currentBudget) async {
    final amount = await AmountEditSheet.show(
      context,
      title: 'Monthly budget',
      subtitle: 'How much do you plan to spend each month?',
      initial: currentBudget,
      confirmLabel: 'Save budget',
    );
    if (amount == null || !mounted) return;

    try {
      await ServiceLocator.instance.api.createBudget({
        'amount': amount,
        'period': 'monthly',
        'category_id': null,
        'rollover': false,
      });
      await MintflowCache.invalidateDashboard();
      if (!mounted) return;
      context.read<DashboardCubit>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Monthly budget set to ${MintflowFormat.currency(amount)}'),
          backgroundColor: MintflowColors.green900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
          margin: const EdgeInsets.all(MintflowSpacing.lg),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: MintflowColors.red,
        ),
      );
    }
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
            return const DashboardSkeleton();
          }
          if (dashState is DashboardError) {
            return ErrorState(
              message: dashState.message,
              onRetry: () => context.read<DashboardCubit>().refresh(),
              foreground: MintflowColors.cream,
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
                onEditBudget: () => _editMonthlyBudget(summary.budgetAmount),
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
                            context.read<BillCubit>().load(forceRefresh: true),
                          ]);
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final expanded =
                                MintBreakpoints.isExpanded(context);
                            // Ring-first: quick actions + summaries + recent.
                            final summaries = <Widget>[
                              const _QuickActions(),
                              const SizedBox(height: MintflowSpacing.lg),
                              _MonthPulse(summary: summary),
                              const SizedBox(height: MintflowSpacing.lg),
                              _CoachingTeaser(summary: summary),
                              const _BillsDueTeaser(),
                            ];
                            final recent = const [
                              _RecentTransactions(),
                              SizedBox(height: MintflowSpacing.sm),
                            ];
                            return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                MintflowSpacing.xl,
                                MintflowSpacing.xl,
                                MintflowSpacing.xl,
                                MintflowSpacing.xxl,
                              ),
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
                                            children: summaries,
                                          ),
                                        ),
                                        const SizedBox(
                                            width: MintflowSpacing.xl),
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
                                      children: [
                                        ...summaries,
                                        const SizedBox(
                                            height: MintflowSpacing.lg),
                                        ...recent,
                                      ],
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
          const SizedBox(width: MintflowSpacing.md),
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Notification settings',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () =>
                    context.push(MintflowRoutes.notificationSettings),
                child: Semantics(
                  button: true,
                  label: 'Notification settings',
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MintflowColors.brandOverlay(context, 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
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
  final VoidCallback onEditBudget;

  const _RingSection({
    required this.progressAnim,
    required this.targetProgress,
    required this.spent,
    required this.budget,
    required this.remaining,
    required this.daysRemaining,
    required this.onEditBudget,
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
      padding: const EdgeInsets.fromLTRB(0, MintflowSpacing.xl, 0, 0),
      child: Column(
        children: [
          SemanticTap(
            label: budget == null
                ? 'Set monthly budget'
                : 'Edit monthly budget, ${MintflowFormat.currency(budget!)}',
            onTap: onEditBudget,
            child: AnimatedBuilder(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: MintflowSpacing.xxl),
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
                            const SizedBox(height: MintflowSpacing.xs),
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
          ),
          const SizedBox(height: MintflowSpacing.sm),
          TextButton(
            onPressed: onEditBudget,
            child: Text(
              budget == null ? 'Set budget' : 'Edit budget',
              style: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.green400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MintflowSpacing.lg,
              0,
              MintflowSpacing.lg,
              MintflowSpacing.xxl,
            ),
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
                    color: MintflowColors.green100,
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

  static final _tipFill = Paint()..color = MintflowColors.green100;
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

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String label, String route})>[
      (icon: Icons.add_rounded, label: 'Add', route: MintflowRoutes.addTx),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Bills',
        route: MintflowRoutes.bills
      ),
      (
        icon: Icons.flag_outlined,
        label: 'Goals',
        route: MintflowRoutes.goals
      ),
      (
        icon: Icons.auto_awesome_outlined,
        label: 'Insights',
        route: MintflowRoutes.insights
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: MintflowSpacing.sm),
          Expanded(
            child: _QuickActionTile(
              icon: items[i].icon,
              label: items[i].label,
              onTap: () {
                final route = items[i].route;
                if (route == MintflowRoutes.addTx) {
                  context.push(route);
                } else if (route == MintflowRoutes.insights) {
                  final user = context.read<UserCubit>().state;
                  final hasAi = user is UserLoaded &&
                      user.user.hasFeature('ai_insights');
                  if (!hasAi) {
                    openUpgradeFlow(context, feature: 'ai_insights');
                    return;
                  }
                  context.go(route);
                } else {
                  context.push(route);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: MintflowRadius.lg_,
          child: Ink(
            height: 72,
            decoration: BoxDecoration(
              color: MintflowColors.mintWash(context),
              borderRadius: MintflowRadius.lg_,
              border: Border.all(color: MintflowColors.hairline(context)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: Icon(icon, size: 22, color: MintflowColors.green600),
                ),
                const SizedBox(height: MintflowSpacing.xs),
                Text(
                  label,
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Month pulse (income / saved / pace) ───────────────────────────────────────

String? _paceLabel(DashboardSummary summary) {
  final projected = summary.projectedSpend;
  final budget = summary.budgetAmount;
  if (projected == null || budget == null || budget <= 0) return null;
  if (projected > budget * 1.02) return 'May overspend';
  if (projected < budget * 0.9) return 'Under pace';
  return 'On pace';
}

IconData _paceIcon(String? label) {
  switch (label) {
    case 'May overspend':
      return Icons.trending_up_rounded;
    case 'Under pace':
      return Icons.trending_down_rounded;
    case 'On pace':
      return Icons.trending_flat_rounded;
    default:
      return Icons.timeline_rounded;
  }
}

class _MonthPulse extends StatelessWidget {
  final DashboardSummary summary;
  const _MonthPulse({required this.summary});

  void _openBreakdown(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardBreakdownScreen(summary: summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pace = _paceLabel(summary);
    final rate = summary.savingsRatePct;
    final savedSubtitle = rate.abs() < 0.05
        ? null
        : '${rate.toStringAsFixed(0)}% rate';

    return MintCard(
      semanticLabel: 'Month summary. Tap for spending breakdown',
      onTap: () => _openBreakdown(context),
      borderRadius: MintflowRadius.xl_,
      padding: const EdgeInsets.symmetric(
        horizontal: MintflowSpacing.md,
        vertical: MintflowSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _PulseCell(
              label: 'In',
              value: MintflowFormat.currency(summary.totalIncome),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: MintflowColors.hairline(context),
          ),
          Expanded(
            child: _PulseCell(
              label: 'Saved',
              value: MintflowFormat.currency(summary.totalSaved),
              subtitle: savedSubtitle,
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: MintflowColors.hairline(context),
          ),
          Expanded(
            child: _PulseCell(
              label: 'Pace',
              value: pace ?? '—',
              icon: _paceIcon(pace),
              warn: pace == 'May overspend',
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseCell extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final bool warn;

  const _PulseCell({
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = warn
        ? MintflowColors.red
        : MintflowColors.textPrimary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MintflowSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MintflowTextStyles.overline.copyWith(
              color: MintflowColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: valueColor),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MintflowTextStyles.labelMedium.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: MintflowTextStyles.overline.copyWith(
                color: MintflowColors.textTertiary(context),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Coaching teaser (insight / needs-wants / pace / add) ──────────────────────

class _CoachingTeaser extends StatefulWidget {
  final DashboardSummary summary;
  const _CoachingTeaser({required this.summary});

  @override
  State<_CoachingTeaser> createState() => _CoachingTeaserState();
}

class _CoachingTeaserState extends State<_CoachingTeaser> {
  bool _dismissed = false;

  void _openBreakdown() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DashboardBreakdownScreen(summary: widget.summary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.summary.topInsight?.trim();
    if (!_dismissed && text != null && text.isNotEmpty) {
      return MintCard(
        color: MintflowColors.green900,
        borderRadius: MintflowRadius.xl_,
        padding: const EdgeInsets.all(MintflowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mintflow insight',
              style: MintflowTextStyles.overline.copyWith(
                color: MintflowColors.green400,
              ),
            ),
            const SizedBox(height: MintflowSpacing.sm),
            Text(
              text,
              style: MintflowTextStyles.bodySmall.copyWith(
                color: MintflowColors.onBrandMuted(context, 0.85),
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
            const SizedBox(height: MintflowSpacing.md),
            Row(
              children: [
                SemanticTap(
                  label: 'Open insights',
                  onTap: () {
                    final user = context.read<UserCubit>().state;
                    final hasAi = user is UserLoaded &&
                        user.user.hasFeature('ai_insights');
                    if (!hasAi) {
                      openUpgradeFlow(context, feature: 'ai_insights');
                      return;
                    }
                    context.go(MintflowRoutes.insights);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintflowSpacing.md,
                      vertical: MintflowSpacing.md,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MintflowColors.green400,
                      borderRadius: MintflowRadius.sm_,
                    ),
                    child: Text(
                      'Open insights',
                      style: MintflowTextStyles.labelSmall.copyWith(
                        color: MintflowColors.onMint(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: MintflowSpacing.sm),
                SemanticTap(
                  label: 'See breakdown',
                  onTap: _openBreakdown,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintflowSpacing.md,
                      vertical: MintflowSpacing.md,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MintflowColors.brandOverlay(context, 0.1),
                      borderRadius: MintflowRadius.sm_,
                    ),
                    child: Text(
                      'Breakdown',
                      style: MintflowTextStyles.labelSmall.copyWith(
                        color: MintflowColors.onBrandMuted(context, 0.65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SemanticTap(
                  label: 'Dismiss insight',
                  onTap: () => setState(() => _dismissed = true),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: MintflowColors.onBrandMuted(context, 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final userState = context.watch<UserCubit>().state;
    final hasNeedsWants = userState is UserLoaded &&
        userState.user.hasFeature('needs_wants');
    final spent = widget.summary.needsTotal + widget.summary.wantsTotal;
    if (hasNeedsWants && spent > 0) {
      return _NeedsWantsTeaser(
        summary: widget.summary,
        onTap: _openBreakdown,
      );
    }

    final pace = _paceLabel(widget.summary);
    if (pace != null && widget.summary.budgetAmount != null) {
      final projected = widget.summary.projectedSpend!;
      final budget = widget.summary.budgetAmount!;
      return MintCard(
        semanticLabel: '$pace. Projected ${MintflowFormat.currency(projected)}',
        onTap: _openBreakdown,
        borderRadius: MintflowRadius.xl_,
        padding: const EdgeInsets.symmetric(
          horizontal: MintflowSpacing.lg,
          vertical: MintflowSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pace == 'May overspend'
                    ? MintflowColors.red.withValues(alpha: 0.12)
                    : MintflowColors.mintWash(context),
                borderRadius: MintflowRadius.md_,
              ),
              child: Icon(
                _paceIcon(pace),
                color: pace == 'May overspend'
                    ? MintflowColors.red
                    : MintflowColors.green600,
                size: 22,
              ),
            ),
            const SizedBox(width: MintflowSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pace, style: MintflowTextStyles.labelMedium),
                  Text(
                    'Projected ${MintflowFormat.currency(projected)} of '
                    '${MintflowFormat.currency(budget)}',
                    style: MintflowTextStyles.overline.copyWith(
                      color: MintflowColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: MintflowColors.textTertiary(context),
              size: 18,
            ),
          ],
        ),
      );
    }

    return MintCard(
      semanticLabel: 'Add a transaction',
      onTap: () => context.push(MintflowRoutes.addTx),
      borderRadius: MintflowRadius.xl_,
      padding: const EdgeInsets.symmetric(
        horizontal: MintflowSpacing.lg,
        vertical: MintflowSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MintflowColors.mintWash(context),
              borderRadius: MintflowRadius.md_,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: MintflowColors.green600,
              size: 22,
            ),
          ),
          const SizedBox(width: MintflowSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add a transaction', style: MintflowTextStyles.labelMedium),
                Text(
                  'Keep your budget ring honest',
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: MintflowColors.textTertiary(context),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _NeedsWantsTeaser extends StatelessWidget {
  final DashboardSummary summary;
  final VoidCallback onTap;

  const _NeedsWantsTeaser({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final needs = summary.needsPct.clamp(0, 100);
    final wants = summary.wantsPct.clamp(0, 100);
    return MintCard(
      semanticLabel:
          'Needs ${needs.toStringAsFixed(0)} percent, wants ${wants.toStringAsFixed(0)} percent',
      onTap: onTap,
      borderRadius: MintflowRadius.xl_,
      padding: const EdgeInsets.all(MintflowSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Needs vs wants',
                  style: MintflowTextStyles.labelMedium,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: MintflowColors.textTertiary(context),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: MintflowSpacing.sm),
          ClipRRect(
            borderRadius: MintflowRadius.pill_,
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Flexible(
                    flex: (needs * 10).round().clamp(1, 1000),
                    child: ColoredBox(color: MintflowColors.green500),
                  ),
                  Flexible(
                    flex: (wants * 10).round().clamp(1, 1000),
                    child: ColoredBox(color: MintflowColors.blue),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MintflowSpacing.sm),
          Row(
            children: [
              Text(
                'Needs ${needs.toStringAsFixed(0)}%',
                style: MintflowTextStyles.overline.copyWith(
                  color: MintflowColors.textSecondary(context),
                ),
              ),
              const Spacer(),
              Text(
                'Wants ${wants.toStringAsFixed(0)}%',
                style: MintflowTextStyles.overline.copyWith(
                  color: MintflowColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bills due teaser (conditional) ────────────────────────────────────────────

class _BillsDueTeaser extends StatelessWidget {
  const _BillsDueTeaser();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillCubit, BillState>(
      buildWhen: (prev, next) => prev != next,
      builder: (context, state) {
        if (state is! BillLoaded) return const SizedBox.shrink();
        final attention = state.billsWithStatus
            .where((b) =>
                b.status == BillStatus.overdue ||
                b.status == BillStatus.unpaid)
            .length;
        final overdue = state.overdueCount;
        if (attention == 0) return const SizedBox.shrink();

        final label = overdue > 0
            ? (overdue == 1
                ? '1 bill is overdue'
                : '$overdue bills are overdue')
            : (attention == 1
                ? '1 bill needs attention'
                : '$attention bills need attention');

        return Padding(
          padding: const EdgeInsets.only(top: MintflowSpacing.lg),
          child: MintCard(
            semanticLabel: label,
            onTap: () => context.push(MintflowRoutes.bills),
            borderRadius: MintflowRadius.xl_,
            padding: const EdgeInsets.symmetric(
              horizontal: MintflowSpacing.lg,
              vertical: MintflowSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: overdue > 0
                        ? MintflowColors.red.withValues(alpha: 0.12)
                        : MintflowColors.mintWash(context),
                    borderRadius: MintflowRadius.md_,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: overdue > 0
                        ? MintflowColors.red
                        : MintflowColors.green600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: MintflowSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: MintflowTextStyles.labelMedium),
                      Text(
                        'Review bills',
                        style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: MintflowColors.textTertiary(context),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
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
                padding: EdgeInsets.symmetric(vertical: MintflowSpacing.lg),
                child: Column(
                  children: [
                    MintSkeleton(height: 56),
                    SizedBox(height: MintflowSpacing.sm),
                    MintSkeleton(height: 56),
                    SizedBox(height: MintflowSpacing.sm),
                    MintSkeleton(height: 56),
                  ],
                ),
              )
            else if (items.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                message: 'Tap + to add one, or link a bank from Profile.',
                actionLabel: 'Add transaction',
                onAction: () => context.push(MintflowRoutes.addTx),
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
