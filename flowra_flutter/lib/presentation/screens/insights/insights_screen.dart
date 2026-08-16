import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../cubits/cubits.dart';

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

  void _load() =>
      context.read<InsightCubit>().load(year: _period.year, month: _period.month);

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

  String get _monthLabel => FlowraFormat.monthYear(_period);

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
        return FlowraColors.green50;
      case 'recommendation':
        return FlowraColors.purpleSoft;
      default:
        return const Color(0xFFFFF8E6);
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'positive':
        return FlowraColors.green500;
      case 'recommendation':
        return FlowraColors.purple;
      default:
        return const Color(0xFFD4A020);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      body: BlocBuilder<InsightCubit, InsightState>(
        builder: (context, state) {
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: FlowraColors.green900,
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          GestureDetector(
                            onTap: _prevMonth,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: FlowraRadius.sm_,
                              ),
                              child: const Icon(Icons.chevron_left,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_monthLabel,
                              style: FlowraTextStyles.labelLarge
                                  .copyWith(color: FlowraColors.cream)),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _nextMonth,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: FlowraRadius.sm_,
                              ),
                              child: Icon(Icons.chevron_right,
                                  color: Colors.white.withOpacity(
                                      DateTime(_period.year, _period.month + 1)
                                              .isAfter(DateTime.now())
                                          ? 0.3
                                          : 1.0),
                                  size: 20),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text('Your month\nin review',
                            style: FlowraTextStyles.displaySmall.copyWith(
                                color: FlowraColors.cream,
                                fontStyle: FontStyle.italic,
                                height: 1.2)),
                        if (state is InsightLoaded) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.insight.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FlowraTextStyles.bodySmall.copyWith(
                              color: FlowraColors.cream.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              title: Text(_monthLabel,
                  style: FlowraTextStyles.labelLarge
                      .copyWith(color: FlowraColors.cream)),
            ),
            if (state is InsightLoading || state is InsightInitial)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
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
                            style: FlowraTextStyles.bodyMedium
                                .copyWith(color: FlowraColors.ink60)),
                        const SizedBox(height: 12),
                        TextButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
              )
            else if (state is InsightLoaded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    ...state.insight.insights.map((item) => _InsightCard(
                          type: item.type,
                          icon: _iconFor(item.type),
                          iconBg: _iconBg(item.type),
                          iconColor: _iconColor(item.type),
                          title: item.title,
                          body: item.body,
                          actionLabel: item.actionLabel,
                        )),
                    ...state.insight.recommendations.map((item) => _InsightCard(
                          type: item.type,
                          icon: _iconFor(item.type),
                          iconBg: _iconBg(item.type),
                          iconColor: _iconColor(item.type),
                          title: item.title,
                          body: item.body,
                          actionLabel: item.actionLabel,
                        )),
                    if (state.insight.insights.isEmpty &&
                        state.insight.recommendations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          state.insight.summary.isNotEmpty
                              ? state.insight.summary
                              : 'No insights for this month yet.',
                          style: FlowraTextStyles.bodyMedium
                              .copyWith(color: FlowraColors.ink60),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _FeedbackCard(
                      thumbsUp: state.insight.thumbsUp,
                      onFeedback: (up) =>
                          context.read<InsightCubit>().submitFeedback(up),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Share.share(
                        'My ${_monthLabel} Flowra summary:\n'
                        '${state.insight.summary}\n\n'
                        'Track yours at flowra.app',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FlowraColors.creamDark,
                          borderRadius: FlowraRadius.lg_,
                          border: Border.all(color: FlowraColors.ink10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.ios_share_outlined,
                                size: 18, color: FlowraColors.ink60),
                            const SizedBox(width: 8),
                            Text(
                              'Share my ${_monthLabel.split(' ').first} recap',
                              style: FlowraTextStyles.labelLarge
                                  .copyWith(color: FlowraColors.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
          ]);
        },
      ),
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
        color: Colors.white,
        borderRadius: FlowraRadius.lg_,
        border: Border.all(color: FlowraColors.ink10),
      ),
      child: Column(children: [
        Text('Were these insights helpful?',
            style: FlowraTextStyles.labelLarge.copyWith(color: FlowraColors.ink)),
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
            style: FlowraTextStyles.bodySmall.copyWith(color: FlowraColors.ink60),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected
              ? (up ? FlowraColors.green50 : FlowraColors.redSoft)
              : FlowraColors.creamDark,
          borderRadius: FlowraRadius.lg_,
          border: Border.all(
            color: selected
                ? (up ? FlowraColors.green400 : FlowraColors.red)
                : FlowraColors.ink10,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Icon(
          up ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
          size: 22,
          color: selected
              ? (up ? FlowraColors.green500 : FlowraColors.red)
              : FlowraColors.ink60,
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
          color: Colors.white,
          borderRadius: FlowraRadius.xl_,
          border: Border.all(color: FlowraColors.ink10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: FlowraRadius.md_),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: FlowraTextStyles.labelLarge
                        .copyWith(color: FlowraColors.ink, height: 1.35))),
          ]),
          const SizedBox(height: 8),
          Text(body,
              style: FlowraTextStyles.bodySmall
                  .copyWith(color: FlowraColors.ink60, height: 1.6)),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            Text(actionLabel!,
                style: FlowraTextStyles.labelSmall
                    .copyWith(color: FlowraColors.green500)),
          ],
        ]),
      );
}
