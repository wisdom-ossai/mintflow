import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/mint_inputs.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/upgrade_soft_gate.dart';

/// Pro debt payoff — snowball / avalanche plan from credit card balances.
class DebtPlanScreen extends StatefulWidget {
  const DebtPlanScreen({super.key});

  @override
  State<DebtPlanScreen> createState() => _DebtPlanScreenState();
}

class _DebtPlanScreenState extends State<DebtPlanScreen> {
  DebtStrategy _strategy = DebtStrategy.avalanche;
  final _extraCtrl = TextEditingController(text: '100');
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserCubit>().state;
      final u = user is UserLoaded ? user.user : null;
      if (u != null && !u.hasFeature('debt_payoff_plan')) {
        openUpgradeFlow(context, feature: 'debt_payoff_plan');
        return;
      }
      context.read<DebtCubit>().load(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final extra = double.tryParse(_extraCtrl.text.trim().replaceAll(',', ''));
    if (extra == null || extra < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid extra payment amount')),
      );
      return;
    }
    setState(() => _generating = true);
    final err = await context.read<DebtCubit>().generate(
          strategy: _strategy.name,
          monthlyExtraPayment: extra,
        );
    if (!mounted) return;
    setState(() => _generating = false);
    if (err != null) {
      if (err.toLowerCase().contains('pro') ||
          err.toLowerCase().contains('upgrade')) {
        await openUpgradeFlow(context, feature: 'debt_payoff_plan');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MintBreakpoints.pageGutter(context);
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Debt plan',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      body: BlocBuilder<DebtCubit, DebtState>(
        builder: (context, state) {
          if (state is DebtLoading || state is DebtInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is DebtError) {
            return ErrorState(
              message: state.message,
              onRetry: () =>
                  context.read<DebtCubit>().load(forceRefresh: true),
            );
          }
          final plan = state is DebtLoaded ? state.plan : null;
          return RefreshIndicator(
            onRefresh: () =>
                context.read<DebtCubit>().load(forceRefresh: true),
            child: ListView(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
              children: [
                MintAdaptiveWidth(
                  maxWidth: MintBreakpoints.contentMax,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Payoff method',
                        style: MintflowTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<DebtStrategy>(
                        segments: const [
                          ButtonSegment(
                            value: DebtStrategy.avalanche,
                            label: Text('Avalanche'),
                            icon: Icon(Icons.trending_down, size: 18),
                          ),
                          ButtonSegment(
                            value: DebtStrategy.snowball,
                            label: Text('Snowball'),
                            icon: Icon(Icons.ac_unit, size: 18),
                          ),
                        ],
                        selected: {_strategy},
                        onSelectionChanged: (s) =>
                            setState(() => _strategy = s.first),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _strategy == DebtStrategy.avalanche
                            ? 'Highest APR first — usually saves the most interest.'
                            : 'Smallest balance first — quick early wins.',
                        style: MintflowTextStyles.bodySmall.copyWith(
                          color: MintflowColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Extra monthly payment',
                        style: MintflowTextStyles.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _extraCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: mintInputDecoration(
                          context,
                          label: 'Extra \$ / month beyond minimums',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generating ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(48, 52),
                          backgroundColor: MintflowColors.green400,
                          foregroundColor: MintflowColors.onMint(context),
                        ),
                        child: _generating
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MintflowColors.onMint(context),
                                ),
                              )
                            : Text(plan == null
                                ? 'Build my plan'
                                : 'Recalculate plan'),
                      ),
                      const SizedBox(height: 28),
                      if (plan == null)
                        EmptyState(
                          icon: Icons.account_balance_outlined,
                          title: 'No plan yet',
                          message:
                              'Add credit cards with balances, then build a snowball or avalanche plan.',
                        )
                      else
                        _PlanResult(plan: plan),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanResult extends StatelessWidget {
  final DebtPlanModel plan;
  const _PlanResult({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintflowColors.green900,
            borderRadius: MintflowRadius.xl_,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debt-free',
                style: MintflowTextStyles.overline.copyWith(
                  color: MintflowColors.onBrandMuted(context, 0.55),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                plan.freedomDateLabel,
                style: MintflowTextStyles.displaySmall
                    .copyWith(color: MintflowColors.cream),
              ),
              const SizedBox(height: 12),
              Text(
                'Interest saved vs minimums: '
                '${MintflowFormat.currency(plan.totalInterestSaved)}',
                style: MintflowTextStyles.bodySmall.copyWith(
                  color: MintflowColors.gold400,
                ),
              ),
              if (plan.aiNarrative != null) ...[
                const SizedBox(height: 12),
                Text(
                  plan.aiNarrative!,
                  style: MintflowTextStyles.bodySmall.copyWith(
                    color: MintflowColors.onBrandMuted(context, 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Payoff order', style: MintflowTextStyles.labelLarge),
        const SizedBox(height: 12),
        ...plan.allocations.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintflowColors.card(context),
                  borderRadius: MintflowRadius.lg_,
                  border: Border.all(color: MintflowColors.hairline(context)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: MintflowColors.mintWash(context),
                      child: Text(
                        '${a.payoffOrder}',
                        style: MintflowTextStyles.labelMedium.copyWith(
                          color: MintflowColors.green600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.accountName,
                              style: MintflowTextStyles.labelLarge),
                          Text(
                            '${MintflowFormat.currency(a.balance)} · '
                            '${a.apr.toStringAsFixed(1)}% APR',
                            style: MintflowTextStyles.bodySmall.copyWith(
                              color: MintflowColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      MintflowFormat.debtFreedom(a.projectedPayoffDate),
                      style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
