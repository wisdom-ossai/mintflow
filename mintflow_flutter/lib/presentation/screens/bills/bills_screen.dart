import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillCubit>().load(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Bills',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(MintflowRoutes.addBill);
          if (mounted) {
            context.read<BillCubit>().load(forceRefresh: true);
          }
        },
        backgroundColor: MintflowColors.green400,
        foregroundColor: MintflowColors.green900,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add bill',
          style: MintflowTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: MintflowColors.green900,
          ),
        ),
      ),
      body: BlocBuilder<BillCubit, BillState>(
        builder: (context, state) {
          if (state is BillLoading || state is BillInitial) {
            return const Center(
              child: CircularProgressIndicator(color: MintflowColors.green400),
            );
          }
          if (state is BillError) {
            return _ErrorBody(
              message: state.message,
              onRetry: () =>
                  context.read<BillCubit>().load(forceRefresh: true),
            );
          }
          if (state is BillLoaded) {
            return RefreshIndicator(
              color: MintflowColors.green400,
              onRefresh: () =>
                  context.read<BillCubit>().load(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  _SummaryHeader(loaded: state),
                  const SizedBox(height: 16),
                  if (state.bills.isEmpty)
                    const _EmptyBills()
                  else
                    ...state.billsWithStatus.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BillCard(item: item),
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
  }
}

class _SummaryHeader extends StatelessWidget {
  final BillLoaded loaded;
  const _SummaryHeader({required this.loaded});

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
                  'This month',
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.cream.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MintflowFormat.currency(loaded.totalMonthly),
                  style: MintflowTextStyles.amountMedium
                      .copyWith(color: MintflowColors.cream),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${loaded.paidCount}/${loaded.bills.length} paid',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.green400),
              ),
              if (loaded.overdueCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${loaded.overdueCount} overdue',
                  style: MintflowTextStyles.overline
                      .copyWith(color: MintflowColors.red),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final BillWithStatus item;
  const _BillCard({required this.item});

  Color get _statusColor {
    switch (item.status) {
      case BillStatus.paid:
        return MintflowColors.green500;
      case BillStatus.overdue:
        return MintflowColors.red;
      case BillStatus.unpaid:
        return MintflowColors.gold400;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.overdue:
        return 'Overdue';
      case BillStatus.unpaid:
        final d = item.daysUntilDue;
        if (d == 0) return 'Due today';
        if (d == 1) return 'Due tomorrow';
        return 'Due in $d days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = item.bill;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.ink10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintflowColors.blueSoft,
                  borderRadius: MintflowRadius.md_,
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: MintflowColors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.name, style: MintflowTextStyles.labelLarge),
                    Text(
                      'Due day ${bill.dueDay}'
                      '${bill.isAutopay ? ' · Autopay' : ''}',
                      style: MintflowTextStyles.overline
                          .copyWith(color: MintflowColors.ink60),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    bill.amount != null
                        ? MintflowFormat.currency(bill.amount!)
                        : '—',
                    style: MintflowTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _statusLabel,
                    style: MintflowTextStyles.overline
                        .copyWith(color: _statusColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (item.status != BillStatus.paid)
                TextButton(
                  onPressed: () => context
                      .read<BillCubit>()
                      .markPaid(bill.id, amountPaid: bill.amount),
                  child: Text(
                    'Mark paid',
                    style: MintflowTextStyles.labelMedium
                        .copyWith(color: MintflowColors.green600),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => _confirmDelete(context, bill),
                child: Text(
                  'Delete',
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

  Future<void> _confirmDelete(BuildContext context, BillModel bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
        title: Text('Delete bill?', style: MintflowTextStyles.labelLarge),
        content: Text(
          '“${bill.name}” will be removed. Payment history for this bill is deleted.',
          style: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.ink60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<BillCubit>().delete(bill.id);
    }
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.ink10),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 40, color: MintflowColors.green500),
          const SizedBox(height: 12),
          Text('No bills yet', style: MintflowTextStyles.labelLarge),
          const SizedBox(height: 6),
          Text(
            'Add rent, utilities, or insurance with a due day. Seed includes 3; Growth is unlimited.',
            textAlign: TextAlign.center,
            style: MintflowTextStyles.bodySmall
                .copyWith(color: MintflowColors.ink60),
          ),
        ],
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
        message.toLowerCase().contains('growth');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: MintflowTextStyles.bodyMedium
                  .copyWith(color: MintflowColors.ink60),
            ),
            const SizedBox(height: 16),
            if (isUpgrade)
              ElevatedButton(
                onPressed: () => context
                    .push('${MintflowRoutes.paywall}?feature=unlimited_bills'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintflowColors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade'),
              )
            else
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
