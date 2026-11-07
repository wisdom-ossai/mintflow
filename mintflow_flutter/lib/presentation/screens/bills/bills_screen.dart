import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';
import '../../widgets/upgrade_soft_gate.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String? _busyBillId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillCubit>().load(forceRefresh: true);
    });
  }

  Future<void> _openAdd() async {
    await context.push(MintflowRoutes.addBill);
    if (mounted) {
      context.read<BillCubit>().load(forceRefresh: true);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markPaid(BillWithStatus item) async {
    if (_busyBillId != null) return;
    setState(() => _busyBillId = item.bill.id);
    final err = await context.read<BillCubit>().markPaid(
          item.bill.id,
          amountPaid: item.bill.amount,
        );
    if (!mounted) return;
    setState(() => _busyBillId = null);
    if (err != null) _snack(err);
  }

  Future<void> _deleteBill(BillModel bill) async {
    if (_busyBillId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MintflowColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
        title: Text('Delete bill?', style: MintflowTextStyles.labelLarge),
        content: Text(
          '“${bill.name}” will be removed. Payment history for this bill is deleted.',
          style: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.textSecondary(context)),
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
    if (ok != true || !mounted) return;
    setState(() => _busyBillId = bill.id);
    final err = await context.read<BillCubit>().delete(bill.id);
    if (!mounted) return;
    setState(() => _busyBillId = null);
    if (err != null) _snack(err);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillCubit, BillState>(
      buildWhen: (prev, next) => prev != next,
      builder: (context, state) {
        final showFab = state is BillLoaded && state.bills.isNotEmpty;
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
          floatingActionButton: showFab
              ? FloatingActionButton.extended(
                  onPressed: _openAdd,
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
                )
              : null,
          body: Builder(
            builder: (context) {
              if (state is BillLoading || state is BillInitial) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: MintflowColors.green400),
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
                final items = state.billsWithStatus;
                final width = MintBreakpoints.widthOf(context);
                final gutter = MintBreakpoints.pageGutter(context);
                final contentW = (width - 2 * gutter)
                    .clamp(0.0, MintBreakpoints.contentMax);
                final sidePad = (width - contentW) / 2;
                final multiCol =
                    MintBreakpoints.isExpanded(context) && items.length > 1;
                final bottom = showFab ? 100.0 : 20.0;

                return RefreshIndicator(
                  color: MintflowColors.green400,
                  onRefresh: () =>
                      context.read<BillCubit>().load(forceRefresh: true),
                  child: state.bills.isEmpty
                      ? ListView(
                          padding: EdgeInsets.fromLTRB(
                              sidePad, 20, sidePad, bottom),
                          children: [_EmptyBills(onAdd: _openAdd)],
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                  sidePad, 20, sidePad, 16),
                              sliver: SliverToBoxAdapter(
                                child: _SummaryHeader(loaded: state),
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
                                          final left = items[i];
                                          final right =
                                              i + 1 < items.length
                                                  ? items[i + 1]
                                                  : null;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: _BillCard(
                                                    key: ValueKey(
                                                        left.bill.id),
                                                    item: left,
                                                    busy: _busyBillId ==
                                                        left.bill.id,
                                                    onMarkPaid: () =>
                                                        _markPaid(left),
                                                    onDelete: () =>
                                                        _deleteBill(
                                                            left.bill),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: right == null
                                                      ? const SizedBox
                                                          .shrink()
                                                      : _BillCard(
                                                          key: ValueKey(
                                                              right
                                                                  .bill.id),
                                                          item: right,
                                                          busy: _busyBillId ==
                                                              right.bill.id,
                                                          onMarkPaid: () =>
                                                              _markPaid(
                                                                  right),
                                                          onDelete: () =>
                                                              _deleteBill(
                                                                  right
                                                                      .bill),
                                                        ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        childCount:
                                            (items.length + 1) ~/ 2,
                                      )
                                    : SliverChildBuilderDelegate(
                                        (context, index) {
                                          final item = items[index];
                                          return Padding(
                                            key: ValueKey(item.bill.id),
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _BillCard(
                                              item: item,
                                              busy: _busyBillId ==
                                                  item.bill.id,
                                              onMarkPaid: () =>
                                                  _markPaid(item),
                                              onDelete: () =>
                                                  _deleteBill(item.bill),
                                            ),
                                          );
                                        },
                                        childCount: items.length,
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
  final bool busy;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  const _BillCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onMarkPaid,
    required this.onDelete,
  });

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
                  color: MintflowColors.blueWash(context),
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
                    Text(
                      bill.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MintflowTextStyles.labelLarge,
                    ),
                    Text(
                      'Due day ${bill.dueDay}'
                      '${bill.isAutopay ? ' · Autopay' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MintflowTextStyles.overline
                          .copyWith(color: MintflowColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                  onPressed: busy ? null : onMarkPaid,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Mark paid',
                          style: MintflowTextStyles.labelMedium
                              .copyWith(color: MintflowColors.green600),
                        ),
                ),
              const Spacer(),
              TextButton(
                onPressed: busy ? null : onDelete,
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
}

class _EmptyBills extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBills({required this.onAdd});

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
          Icon(Icons.receipt_long_outlined,
              size: 40, color: MintflowColors.green500),
          const SizedBox(height: 12),
          Text('No bills yet', style: MintflowTextStyles.labelLarge),
          const SizedBox(height: 6),
          Text(
            'Rent, utilities, insurance — with a due day. Seed includes 3.',
            textAlign: TextAlign.center,
            style: MintflowTextStyles.bodySmall
                .copyWith(color: MintflowColors.textSecondary(context)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAdd,
              child: const Text('Add your first bill'),
            ),
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
                  .copyWith(color: MintflowColors.textSecondary(context)),
            ),
            const SizedBox(height: 16),
            if (isUpgrade)
              ElevatedButton(
                onPressed: () => openUpgradeFlow(
                  context,
                  feature: 'unlimited_bills',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintflowColors.purple,
                  foregroundColor: MintflowColors.cream,
                ),
                child: const Text('See Growth plans'),
              )
            else
              TextButton(
                  onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
