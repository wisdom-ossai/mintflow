import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';

class RecurringSubscriptionsScreen extends StatelessWidget {
  const RecurringSubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RecurringCubit()..load(),
      child: const _RecurringBody(),
    );
  }
}

class _RecurringBody extends StatelessWidget {
  const _RecurringBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Subscriptions',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan transactions',
            onPressed: () => context.read<RecurringCubit>().detect(),
            icon: const Icon(Icons.radar_rounded),
          ),
        ],
      ),
      body: BlocBuilder<RecurringCubit, RecurringState>(
        builder: (context, state) {
          if (state is RecurringLoading || state is RecurringInitial) {
            return const Center(
              child: CircularProgressIndicator(color: MintflowColors.green400),
            );
          }
          if (state is RecurringUpgradeRequired) {
            return _UpgradeState(
              onUpgrade: () => context
                  .push('${MintflowRoutes.paywall}?feature=subscription_tracker'),
            );
          }
          if (state is RecurringError) {
            return _ErrorState(
              message: state.message,
              onRetry: () => context.read<RecurringCubit>().load(),
            );
          }
          if (state is RecurringLoaded) {
            return _LoadedView(data: state.data);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final RecurringSubscriptionList data;
  const _LoadedView({required this.data});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: MintflowColors.green400,
      onRefresh: () => context.read<RecurringCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _SummaryCard(
            monthlyTotal: data.monthlyTotal,
            activeCount: data.activeCount,
          ),
          const SizedBox(height: 16),
          Text(
            data.items.isEmpty
                ? 'No subscriptions detected yet'
                : 'Detected from your linked accounts',
            style: MintflowTextStyles.bodySmall
                .copyWith(color: MintflowColors.ink60),
          ),
          const SizedBox(height: 12),
          if (data.items.isEmpty)
            _EmptyCard(
              onScan: () => context.read<RecurringCubit>().detect(),
            )
          else
            ...data.items.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SubCard(sub: s),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double monthlyTotal;
  final int activeCount;
  const _SummaryCard({
    required this.monthlyTotal,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintflowColors.green900,
        borderRadius: MintflowRadius.xl_,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Est. monthly',
                  style: MintflowTextStyles.overline
                      .copyWith(color: MintflowColors.cream.withOpacity(0.55)),
                ),
                const SizedBox(height: 4),
                Text(
                  MintflowFormat.currency(monthlyTotal),
                  style: MintflowTextStyles.amountMedium
                      .copyWith(color: MintflowColors.cream),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: MintflowRadius.lg_,
            ),
            child: Text(
              '$activeCount active',
              style: MintflowTextStyles.labelMedium
                  .copyWith(color: MintflowColors.green400),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  final RecurringSubscriptionModel sub;
  const _SubCard({required this.sub});

  String get _freqLabel {
    switch (sub.frequency) {
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.yearly:
        return 'Yearly';
      case RecurringFrequency.monthly:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = sub.nextExpectedAt != null
        ? 'Next ~ ${MintflowFormat.dateShort(sub.nextExpectedAt!)}'
        : '$_freqLabel · ${sub.occurrenceCount} charges';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.hairline(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintflowColors.purpleWash(context),
                  borderRadius: MintflowRadius.md_,
                ),
                child: const Icon(Icons.autorenew_rounded,
                    color: MintflowColors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.displayName, style: MintflowTextStyles.labelLarge),
                    Text(
                      next,
                      style: MintflowTextStyles.overline
                          .copyWith(color: MintflowColors.ink60),
                    ),
                  ],
                ),
              ),
              Text(
                MintflowFormat.currency(sub.typicalAmount),
                style: MintflowTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _freqLabel,
                style: MintflowTextStyles.overline
                    .copyWith(color: MintflowColors.ink60),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context
                    .read<RecurringCubit>()
                    .setStatus(sub.id, 'cancelled'),
                child: Text(
                  'Cancel',
                  style: MintflowTextStyles.labelMedium
                      .copyWith(color: MintflowColors.ink60),
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.read<RecurringCubit>().dismiss(sub.id),
                child: Text(
                  'Not a sub',
                  style: MintflowTextStyles.labelMedium
                      .copyWith(color: MintflowColors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyCard({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.hairline(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.subscriptions_outlined,
              size: 40, color: MintflowColors.green500),
          const SizedBox(height: 12),
          Text('Scan your transactions', style: MintflowTextStyles.labelLarge),
          const SizedBox(height: 6),
          Text(
            'We look for merchants that charge you on a steady weekly or monthly cadence after bank sync.',
            textAlign: TextAlign.center,
            style: MintflowTextStyles.bodySmall
                .copyWith(color: MintflowColors.ink60),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: MintflowColors.green400,
                foregroundColor: MintflowColors.green900,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: MintflowRadius.lg_),
              ),
              child: Text(
                'Scan now',
                style: MintflowTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: MintflowColors.green900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeState extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _UpgradeState({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 40, color: MintflowColors.purple),
            const SizedBox(height: 12),
            Text('Subscription tracker is on Growth+',
                style: MintflowTextStyles.labelLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Auto-detect Netflix, Spotify, and other monthly charges from your linked banks.',
              textAlign: TextAlign.center,
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.ink60),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: MintflowColors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
                    .copyWith(color: MintflowColors.ink60)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
