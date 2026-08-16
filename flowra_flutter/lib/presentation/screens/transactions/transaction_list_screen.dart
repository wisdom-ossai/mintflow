import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transaction List Screen — wired to TransactionCubit
// ─────────────────────────────────────────────────────────────────────────────

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});
  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Expenses', 'Income', 'Needs', 'Wants'];
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  String get _apiFilter {
    switch (_filter) {
      case 'Expenses':
        return 'expenses';
      case 'Income':
        return 'income';
      case 'Needs':
        return 'needs';
      case 'Wants':
        return 'wants';
      default:
        return 'all';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionCubit>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, List<TransactionModel>> _groupByDate(
      List<TransactionModel> items) {
    final map = <String, List<TransactionModel>>{};
    for (final tx in items) {
      final key = FlowraFormat.relativeDate(tx.date) == 'Today' ||
              FlowraFormat.relativeDate(tx.date) == 'Yesterday'
          ? '${FlowraFormat.relativeDate(tx.date)} — ${FlowraFormat.dateShort(tx.date)}'
          : FlowraFormat.dateShort(tx.date);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: FlowraColors.green900,
                title: Text('Transactions',
                    style: FlowraTextStyles.displaySmall
                        .copyWith(color: FlowraColors.cream)),
                actions: [
                  IconButton(
                    icon: Icon(
                      _showSearch ? Icons.close : Icons.search,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchCtrl.clear();
                          context
                              .read<TransactionCubit>()
                              .load(filter: _apiFilter);
                        }
                      });
                    },
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize:
                      Size.fromHeight(_showSearch ? 100 : 52),
                  child: Column(
                    children: [
                      if (_showSearch)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search merchants…',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.5)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: FlowraRadius.lg_,
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                            onSubmitted: (q) => context
                                .read<TransactionCubit>()
                                .search(q),
                          ),
                        ),
                      Container(
                        color: FlowraColors.green900,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final f = _filters[i];
                              final active = _filter == f;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _filter = f);
                                  final api = switch (f) {
                                    'Expenses' => 'expenses',
                                    'Income' => 'income',
                                    'Needs' => 'needs',
                                    'Wants' => 'wants',
                                    _ => 'all',
                                  };
                                  context
                                      .read<TransactionCubit>()
                                      .applyFilter(api);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? FlowraColors.green400
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: FlowraRadius.pill_,
                                    border: Border.all(
                                      color: active
                                          ? FlowraColors.green400
                                          : Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(f,
                                      style: FlowraTextStyles.labelSmall
                                          .copyWith(
                                        color: Colors.white,
                                        fontWeight: active
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      )),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state is TransactionLoading && !state.isPaginating)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state is TransactionError)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message,
                            style: FlowraTextStyles.bodyMedium
                                .copyWith(color: FlowraColors.ink60)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context
                              .read<TransactionCubit>()
                              .load(filter: _apiFilter),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (state is TransactionLoaded) ...[
                if (state.items.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: FlowraTextStyles.bodyMedium
                            .copyWith(color: FlowraColors.ink60),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final groups = _groupByDate(state.items);
                        final keys = groups.keys.toList();
                        if (i >= keys.length) return null;
                        final key = keys[i];
                        final txs = groups[key]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              color: FlowraColors.creamDark,
                              child: Text(key,
                                  style: FlowraTextStyles.overline.copyWith(
                                      color: FlowraColors.ink60,
                                      fontWeight: FontWeight.w500)),
                            ),
                            ...txs.asMap().entries.map((e) {
                              final tx = e.value;
                              final isLast = e.key == txs.length - 1;
                              return Column(children: [
                                _TxRow(tx: tx),
                                if (!isLast)
                                  const Divider(
                                      height: 1,
                                      indent: 72,
                                      color: FlowraColors.ink10),
                              ]);
                            }),
                          ],
                        );
                      },
                      childCount: _groupByDate(state.items).length,
                    ),
                  ),
                if (state.hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: () =>
                            context.read<TransactionCubit>().loadMore(),
                        child: const Text('Load more'),
                      ),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCC = tx.isCreditCardPayment;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCC
                ? const Color(0xFFF5F0FF)
                : tx.isIncome
                    ? FlowraColors.green50
                    : FlowraColors.creamDark,
            borderRadius: FlowraRadius.md_,
          ),
          child: Icon(
            isCC
                ? Icons.credit_card_outlined
                : tx.isIncome
                    ? Icons.trending_up
                    : Icons.receipt_long_outlined,
            size: 18,
            color: isCC
                ? FlowraColors.purple
                : tx.isIncome
                    ? FlowraColors.green500
                    : FlowraColors.ink60,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.displayName,
                  style: FlowraTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500, color: FlowraColors.ink)),
              const SizedBox(height: 2),
              Row(children: [
                Text(
                  isCC
                      ? 'CC payment — excluded'
                      : (tx.category?.name ??
                          (tx.isIncome ? 'Income' : 'Expense')),
                  style: isCC
                      ? FlowraTextStyles.overline.copyWith(
                          color: FlowraColors.purple,
                          fontWeight: FontWeight.w500)
                      : FlowraTextStyles.overline
                          .copyWith(color: FlowraColors.ink60),
                ),
                if (tx.isNeed != null) ...[
                  const SizedBox(width: 4),
                  _NeedWantTag(isNeed: tx.isNeed!),
                ],
              ]),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            tx.isIncome
                ? '+${FlowraFormat.currency(tx.amount)}'
                : isCC
                    ? FlowraFormat.currency(tx.amount)
                    : '-${FlowraFormat.currency(tx.amount)}',
            style: FlowraTextStyles.labelLarge.copyWith(
              color: tx.isIncome
                  ? FlowraColors.green400
                  : isCC
                      ? FlowraColors.ink60
                      : FlowraColors.ink,
              fontSize: isCC ? 12 : 14,
            ),
          ),
          if (tx.aiCategorized)
            Row(children: [
              const Icon(Icons.auto_awesome,
                  size: 10, color: FlowraColors.green400),
              const SizedBox(width: 2),
              Text('AI',
                  style: FlowraTextStyles.overline
                      .copyWith(color: FlowraColors.green400, fontSize: 9)),
            ]),
        ]),
      ]),
    );
  }
}

class _NeedWantTag extends StatelessWidget {
  final bool isNeed;
  const _NeedWantTag({required this.isNeed});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: isNeed ? FlowraColors.green50 : const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isNeed ? 'need' : 'want',
          style: FlowraTextStyles.overline.copyWith(
            fontSize: 9,
            color: isNeed ? FlowraColors.green600 : const Color(0xFF9A6200),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
