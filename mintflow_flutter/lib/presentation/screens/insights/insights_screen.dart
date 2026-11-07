import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/format.dart';
import '../../cubits/cubits.dart';
import '../../widgets/upgrade_soft_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Insights Screen — wired to InsightCubit
// ─────────────────────────────────────────────────────────────────────────────

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late DateTime _period;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final userState = context.read<UserCubit>().state;
    if (userState is UserLoaded && !userState.user.hasFeature('ai_insights')) {
      context.read<InsightCubit>().requireUpgrade();
      return;
    }
    context.read<InsightCubit>().load(year: _period.year, month: _period.month);
  }

  void _prevMonth() {
    setState(() => _period = DateTime(_period.year, _period.month - 1));
    _load();
  }

  void _nextMonth() {
    final next = DateTime(_period.year, _period.month + 1);
    if (!next.isAfter(DateTime.now())) {
      setState(() => _period = next);
      _load();
    }
  }

  String get _monthLabel => MintflowFormat.monthYear(_period);

  IconData _iconFor(String type) {
    switch (type) {
      case 'positive':
        return Icons.check_circle_outline;
      case 'recommendation':
        return Icons.lightbulb_outline;
      case 'warning':
      default:
        return Icons.trending_up;
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'positive':
        return MintflowColors.mintWash(context);
      case 'recommendation':
        return MintflowColors.purpleWash(context);
      default:
        return MintflowColors.wantWash(context);
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'positive':
        return MintflowColors.green500;
      case 'recommendation':
        return MintflowColors.purple;
      default:
        return MintflowColors.wantLabel(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: BlocBuilder<InsightCubit, InsightState>(
        buildWhen: (prev, next) => prev != next,
        builder: (context, state) {
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: MintflowColors.green900,
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Semantics(
                            button: true,
                            label: 'Previous month',
                            child: IconButton(
                              tooltip: 'Previous month',
                              onPressed: _prevMonth,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    MintflowColors.brandOverlay(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: MintflowRadius.sm_,
                                ),
                              ),
                              icon: Icon(Icons.chevron_left,
                                  color: MintflowColors.onBrand(context),
                                  size: 22),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(_monthLabel,
                              style: MintflowTextStyles.labelLarge
                                  .copyWith(color: MintflowColors.cream)),
                          const SizedBox(width: 4),
                          Semantics(
                            button: true,
                            label: 'Next month',
                            child: IconButton(
                              tooltip: 'Next month',
                              onPressed: DateTime(
                                          _period.year, _period.month + 1)
                                      .isAfter(DateTime.now())
                                  ? null
                                  : _nextMonth,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    MintflowColors.brandOverlay(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: MintflowRadius.sm_,
                                ),
                              ),
                              icon: Icon(
                                Icons.chevron_right,
                                color: MintflowColors.onBrand(context)
                                    .withValues(
                                  alpha: DateTime(_period.year, _period.month + 1)
                                          .isAfter(DateTime.now())
                                      ? 0.35
                                      : 1.0,
                                ),
                                size: 22,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text('Your month\nin review',
                            style: MintflowTextStyles.displaySmall.copyWith(
                                color: MintflowColors.cream,
                                fontStyle: FontStyle.italic,
                                height: 1.2)),
                        if (state is InsightLoaded) ...[
                          const SizedBox(height: 4),
                          Text(
                            state.insight.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MintflowTextStyles.bodySmall.copyWith(
                              color: MintflowColors.onBrandMuted(context, 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(_monthLabel,
                  style: MintflowTextStyles.labelLarge
                      .copyWith(color: MintflowColors.cream)),
            ),
            if (state is InsightLoading || state is InsightInitial)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state is InsightUpgradeRequired)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: MintflowColors.mintWash(context),
                          borderRadius: MintflowRadius.xl_,
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: MintflowColors.green500, size: 28),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Monthly AI insights',
                        style: MintflowTextStyles.labelLarge
                            .copyWith(color: MintflowColors.textPrimary(context)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock Growth to get a plain-English review of your spending each month.',
                        style: MintflowTextStyles.bodySmall
                            .copyWith(color: MintflowColors.textSecondary(context), height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => openUpgradeFlow(
                          context,
                          feature: 'ai_insights',
                        ),
                        child: const Text('See Growth plans'),
                      ),
                    ],
                  ),
                ),
              )
            else if (state is InsightError)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message,
                            textAlign: TextAlign.center,
                            style: MintflowTextStyles.bodyMedium
                                .copyWith(color: MintflowColors.textSecondary(context))),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _load,
                            child: const Text('Try again')),
                      ],
                    ),
                  ),
                ),
              )
            else if (state is InsightLoaded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _InsightBody(
                    monthLabel: _monthLabel,
                    state: state,
                    iconFor: _iconFor,
                    iconBg: _iconBg,
                    iconColor: _iconColor,
                    onFeedback: (up) =>
                        context.read<InsightCubit>().submitFeedback(up),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _InsightBody extends StatelessWidget {
  final String monthLabel;
  final InsightLoaded state;
  final IconData Function(String) iconFor;
  final Color Function(String) iconBg;
  final Color Function(String) iconColor;
  final ValueChanged<bool> onFeedback;

  const _InsightBody({
    required this.monthLabel,
    required this.state,
    required this.iconFor,
    required this.iconBg,
    required this.iconColor,
    required this.onFeedback,
  });

  List<Widget> _cards(BuildContext context) {
    final items = [
      ...state.insight.insights,
      ...state.insight.recommendations,
    ];
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            state.insight.summary.isNotEmpty
                ? state.insight.summary
                : 'No insights for this month yet. Add a few transactions, then check back.',
            style: MintflowTextStyles.bodyMedium
                .copyWith(color: MintflowColors.textSecondary(context)),
          ),
        ),
      ];
    }
    return [
      for (final item in items)
        _InsightCard(
          type: item.type,
          icon: iconFor(item.type),
          iconBg: iconBg(item.type),
          iconColor: iconColor(item.type),
          title: item.title,
          body: item.body,
          actionLabel: item.actionLabel,
        ),
    ];
  }

  Widget _shareButton(BuildContext context) {
    final shortMonth = monthLabel.split(' ').first;
    return Semantics(
      button: true,
      label: 'Share my $shortMonth recap',
      child: Material(
        color: MintflowColors.softFill(context),
        borderRadius: MintflowRadius.lg_,
        child: InkWell(
          borderRadius: MintflowRadius.lg_,
          onTap: () => SharePlus.instance.share(
            ShareParams(
              text: 'My $monthLabel Mintflow summary:\n'
                  '${state.insight.summary}\n\n'
                  'Track yours at mintflow.app',
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: MintflowRadius.lg_,
              border: Border.all(color: MintflowColors.hairline(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ios_share_outlined,
                    size: 18, color: MintflowColors.textSecondary(context)),
                const SizedBox(width: 8),
                Text(
                  'Share my $shortMonth recap',
                  style: MintflowTextStyles.labelLarge
                      .copyWith(color: MintflowColors.textPrimary(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expanded = MintBreakpoints.isExpanded(context);
    final cards = _cards(context);
    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FeedbackCard(
          thumbsUp: state.insight.thumbsUp,
          onFeedback: onFeedback,
        ),
        const SizedBox(height: 12),
        _shareButton(context),
      ],
    );

    if (!expanded) {
      return Column(
        children: [
          ...cards,
          const SizedBox(height: 16),
          sidebar,
          const SizedBox(height: 80),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 0,
                    children: [
                      for (final card in cards)
                        SizedBox(width: cardWidth, child: card),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 20),
            Expanded(flex: 2, child: sidebar),
          ],
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final bool? thumbsUp;
  final ValueChanged<bool> onFeedback;
  const _FeedbackCard({required this.thumbsUp, required this.onFeedback});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        borderRadius: MintflowRadius.lg_,
        border: Border.all(color: MintflowColors.hairline(context)),
      ),
      child: Column(children: [
        Text('Were these insights helpful?',
            style: MintflowTextStyles.labelLarge
                .copyWith(color: MintflowColors.textPrimary(context))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Thumb(
            up: true,
            selected: thumbsUp == true,
            onTap: () => onFeedback(true),
          ),
          const SizedBox(width: 12),
          _Thumb(
            up: false,
            selected: thumbsUp == false,
            onTap: () => onFeedback(false),
          ),
        ]),
        if (thumbsUp != null) ...[
          const SizedBox(height: 10),
          Text(
            thumbsUp!
                ? 'Thanks! Glad this was useful.'
                : 'Thanks for the feedback — we\'ll improve.',
            style: MintflowTextStyles.bodySmall.copyWith(color: MintflowColors.textSecondary(context)),
          ),
        ],
      ]),
    );
  }
}

class _Thumb extends StatelessWidget {
  final bool up;
  final bool selected;
  final VoidCallback onTap;
  const _Thumb({required this.up, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? (up
            ? MintflowColors.mintWash(context)
            : MintflowColors.redWash(context))
        : MintflowColors.softFill(context);
    return Semantics(
      button: true,
      selected: selected,
      label: up ? 'Helpful' : 'Not helpful',
      child: Material(
        color: fill,
        borderRadius: MintflowRadius.lg_,
        child: InkWell(
          borderRadius: MintflowRadius.lg_,
          onTap: onTap,
          child: AnimatedContainer(
            duration: MintMotion.duration(
              context,
              const Duration(milliseconds: 200),
            ),
            curve: MintMotion.curve(context),
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: MintflowRadius.lg_,
              border: Border.all(
                color: selected
                    ? (up ? MintflowColors.green400 : MintflowColors.red)
                    : MintflowColors.hairline(context),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Icon(
              up ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
              size: 22,
              color: selected
                  ? (up ? MintflowColors.green500 : MintflowColors.red)
                  : MintflowColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String type, title, body;
  final IconData icon;
  final Color iconBg, iconColor;
  final String? actionLabel;
  const _InsightCard({
    required this.type,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.body,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintflowColors.card(context),
          borderRadius: MintflowRadius.xl_,
          border: Border.all(color: MintflowColors.hairline(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: MintflowRadius.md_),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: MintflowTextStyles.labelLarge.copyWith(
                        color: MintflowColors.textPrimary(context),
                        height: 1.35))),
          ]),
          const SizedBox(height: 8),
          Text(body,
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.textSecondary(context), height: 1.6)),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            Text(actionLabel!,
                style: MintflowTextStyles.labelSmall
                    .copyWith(color: MintflowColors.green500)),
          ],
        ]),
      );
}
