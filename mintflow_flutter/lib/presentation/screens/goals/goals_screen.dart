import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/upgrade_soft_gate.dart';

/// Savings goals — first-use empty state guides activation. No mock amounts.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String? _busyGoalId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalCubit>().load(forceRefresh: true);
    });
  }

  Future<void> _openAdd() async {
    await context.push(MintflowRoutes.addGoal);
    if (mounted) {
      context.read<GoalCubit>().load(forceRefresh: true);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GoalCubit, GoalState>(
      buildWhen: (prev, next) => prev != next,
      builder: (context, state) {
        final showFab = state is GoalLoaded && state.goals.isNotEmpty;
        return Scaffold(
          backgroundColor: MintflowColors.page(context),
          appBar: AppBar(
            backgroundColor: MintflowColors.green900,
            foregroundColor: MintflowColors.cream,
            title: Text(
              'Goals',
              style: MintflowTextStyles.displaySmall
                  .copyWith(color: MintflowColors.cream),
            ),
          ),
          floatingActionButton: showFab
              ? FloatingActionButton.extended(
                  onPressed: _openAdd,
                  backgroundColor: MintflowColors.green400,
                  foregroundColor: MintflowColors.green900,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Add goal',
                    style: MintflowTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MintflowColors.green900,
                    ),
                  ),
                )
              : null,
          body: Builder(
            builder: (context) {
              if (state is GoalLoading || state is GoalInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: MintflowColors.green400),
                );
              }
              if (state is GoalError) {
                return _ErrorBody(
                  message: state.message,
                  onRetry: () =>
                      context.read<GoalCubit>().load(forceRefresh: true),
                );
              }
              if (state is GoalLoaded) {
                final goals = state.goals;
                final width = MintBreakpoints.widthOf(context);
                final gutter = MintBreakpoints.pageGutter(context);
                final contentW = (width - 2 * gutter)
                    .clamp(0.0, MintBreakpoints.contentMax);
                final sidePad = (width - contentW) / 2;
                final multiCol =
                    MintBreakpoints.isExpanded(context) && goals.length > 1;
                final bottom = showFab ? 100.0 : 20.0;

                return RefreshIndicator(
                  color: MintflowColors.green400,
                  onRefresh: () =>
                      context.read<GoalCubit>().load(forceRefresh: true),
                  child: goals.isEmpty
                      ? ListView(
                          padding: EdgeInsets.fromLTRB(
                              sidePad, 20, sidePad, bottom),
                          children: [_EmptyGoals(onAdd: _openAdd)],
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                  sidePad, 20, sidePad, 12),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  '${goals.length} active · Tap to contribute',
                                  style: MintflowTextStyles.bodySmall.copyWith(
                                    color: MintflowColors
                                        .textSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                  sidePad, 0, sidePad, bottom),
                              sliver: SliverList(
                                delegate: multiCol
                                    ? SliverChildBuilderDelegate(
                                        (context, index) {
                                          final i = index * 2;
                                          final left = goals[i];
                                          final right = i + 1 < goals.length
                                              ? goals[i + 1]
                                              : null;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: _GoalCard(
                                                    key: ValueKey(left.id),
                                                    goal: left,
                                                    busy: _busyGoalId ==
                                                        left.id,
                                                    onContribute: () =>
                                                        _contribute(left),
                                                    onDelete: () =>
                                                        _confirmDelete(left),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: right == null
                                                      ? const SizedBox
                                                          .shrink()
                                                      : _GoalCard(
                                                          key: ValueKey(
                                                              right.id),
                                                          goal: right,
                                                          busy: _busyGoalId ==
                                                              right.id,
                                                          onContribute: () =>
                                                              _contribute(
                                                                  right),
                                                          onDelete: () =>
                                                              _confirmDelete(
                                                                  right),
                                                        ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        childCount:
                                            (goals.length + 1) ~/ 2,
                                      )
                                    : SliverChildBuilderDelegate(
                                        (context, index) {
                                          final g = goals[index];
                                          return Padding(
                                            key: ValueKey(g.id),
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _GoalCard(
                                              goal: g,
                                              busy: _busyGoalId == g.id,
                                              onContribute: () =>
                                                  _contribute(g),
                                              onDelete: () =>
                                                  _confirmDelete(g),
                                            ),
                                          );
                                        },
                                        childCount: goals.length,
                                      ),
                              ),
                            ),
                          ],
                        ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Future<void> _contribute(SavingsGoalModel goal) async {
    if (_busyGoalId != null) return;
    final ctrl = TextEditingController();
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MintflowColors.page(context),
      constraints: const BoxConstraints(maxWidth: MintBreakpoints.formMax),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add to ${goal.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MintflowTextStyles.displaySmall.copyWith(
                  color: MintflowColors.textPrimary(sheetContext),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remaining ${MintflowFormat.currency(goal.remaining)}',
                style: MintflowTextStyles.bodySmall.copyWith(
                  color: MintflowColors.textSecondary(sheetContext),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 14,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  counterText: '',
                  filled: true,
                  fillColor: MintflowColors.card(sheetContext),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final raw = ctrl.text.trim().replaceAll(',', '');
                  final v = double.tryParse(raw);
                  if (v == null || v <= 0) return;
                  Navigator.pop(sheetContext, v);
                },
                child: const Text('Add contribution'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (amount == null || !mounted) return;
    setState(() => _busyGoalId = goal.id);
    final err =
        await context.read<GoalCubit>().contribute(goal.id, amount);
    if (!mounted) return;
    setState(() => _busyGoalId = null);
    if (err != null) _snack(err);
  }

  Future<void> _confirmDelete(SavingsGoalModel goal) async {
    if (_busyGoalId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text(
          '“${goal.name}” and its progress will be removed. This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MintflowColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete goal'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyGoalId = goal.id);
    final err = await context.read<GoalCubit>().delete(goal.id);
    if (!mounted) return;
    setState(() => _busyGoalId = null);
    if (err != null) _snack(err);
  }
}

class _EmptyGoals extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyGoals({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.savings_outlined,
      title: 'No goals yet',
      message: 'Name a target and an amount. Seed includes 1 goal.',
      iconColor: MintflowColors.green500,
      iconBg: MintflowColors.mintWash(context),
      actionLabel: 'Add goal',
      onAction: onAdd,
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoalModel goal;
  final bool busy;
  final VoidCallback onContribute;
  final VoidCallback onDelete;

  const _GoalCard({
    super.key,
    required this.goal,
    required this.busy,
    required this.onContribute,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (goal.progressPct / 100).clamp(0.0, 1.0);
    return Material(
      color: MintflowColors.card(context),
      borderRadius: MintflowRadius.xl_,
      child: Semantics(
        button: true,
        enabled: !busy,
        label: 'Add contribution to ${goal.name}',
        child: InkWell(
          borderRadius: MintflowRadius.xl_,
          onTap: busy ? null : onContribute,
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: MintflowRadius.xl_,
            border: Border.all(color: MintflowColors.hairline(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MintflowTextStyles.labelLarge.copyWith(
                        color: MintflowColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MintflowColors.green400,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Delete goal',
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: MintflowColors.textTertiary(context),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: MintflowRadius.pill_,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: MintflowColors.softFill(context),
                  color: goal.isCompleted
                      ? MintflowColors.green500
                      : MintflowColors.green400,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${MintflowFormat.currency(goal.currentAmount)} of ${MintflowFormat.currency(goal.targetAmount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MintflowTextStyles.bodySmall.copyWith(
                        color: MintflowColors.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    goal.isCompleted
                        ? 'Complete'
                        : MintflowFormat.percentage(goal.progressPct),
                    style: MintflowTextStyles.labelMedium.copyWith(
                      color: MintflowColors.green600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (goal.projectedCompletionLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  goal.projectedCompletionLabel!,
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Tap to add a contribution',
                style: MintflowTextStyles.overline.copyWith(
                  color: MintflowColors.textSecondary(context),
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

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isUpgrade = message.toLowerCase().contains('upgrade') ||
        message.toLowerCase().contains('growth') ||
        message.toLowerCase().contains('limit');
    if (!isUpgrade) {
      return ErrorState(message: message, onRetry: onRetry);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MintflowSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: MintflowTextStyles.bodyMedium.copyWith(
                color: MintflowColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: MintflowSpacing.lg),
            ElevatedButton(
              onPressed: () => openUpgradeFlow(
                context,
                feature: 'unlimited_goals',
              ),
              child: const Text('See Growth plans'),
            ),
          ],
        ),
      ),
    );
  }
}
