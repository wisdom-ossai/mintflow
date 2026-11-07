import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Transaction List Screen — wired to TransactionCubit
// Compact: single-column list. Expanded (≥840): master–detail split.
// ─────────────────────────────────────────────────────────────────────────────

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});
  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  String? _selectedId;

  static const _filters = <_TxFilter>[
    _TxFilter(id: 'All', api: 'all'),
    _TxFilter(id: 'Expenses', api: 'expenses'),
    _TxFilter(id: 'Income', api: 'income'),
    _TxFilter(id: 'Needs', api: 'needs'),
    _TxFilter(id: 'Wants', api: 'wants'),
  ];

  String get _apiFilter {
    for (final f in _filters) {
      if (f.id == _filter) return f.api;
    }
    return 'all';
  }

  void _onFilterSelected(String id) {
    if (_filter == id) return;
    setState(() {
      _filter = id;
      _selectedId = null;
    });
    context.read<TransactionCubit>().applyFilter(_apiFilter);
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
      final key = MintflowFormat.relativeDate(tx.date) == 'Today' ||
              MintflowFormat.relativeDate(tx.date) == 'Yesterday'
          ? '${MintflowFormat.relativeDate(tx.date)} — ${MintflowFormat.dateShort(tx.date)}'
          : MintflowFormat.dateShort(tx.date);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }

  TransactionModel? _findSelected(List<TransactionModel> items) {
    if (_selectedId == null) return null;
    for (final tx in items) {
      if (tx.id == _selectedId) return tx;
    }
    return null;
  }

  PreferredSizeWidget? _appBarBottom(BuildContext context) {
    if (!_showSearch) return null;
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: MintflowColors.onBrand(context)),
          decoration: InputDecoration(
            labelText: 'Search merchants',
            hintText: 'Starbucks, Amazon…',
            hintStyle:
                TextStyle(color: MintflowColors.onBrandMuted(context)),
            labelStyle:
                TextStyle(color: MintflowColors.onBrandMuted(context)),
            filled: true,
            fillColor: MintflowColors.brandOverlay(context),
            border: OutlineInputBorder(
              borderRadius: MintflowRadius.lg_,
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: (q) => context.read<TransactionCubit>().search(q),
        ),
      ),
    );
  }

  Widget _listSlivers(BuildContext context, TransactionState state,
      {required bool selectable}) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MintflowColors.green900,
          title: Text('Transactions',
              style: MintflowTextStyles.displaySmall
                  .copyWith(color: MintflowColors.cream)),
          actions: [
            IconButton(
              tooltip:
                  _showSearch ? 'Close search' : 'Search transactions',
              icon: Icon(
                _showSearch ? Icons.close : Icons.search,
                color: MintflowColors.onBrand(context),
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
          bottom: _appBarBottom(context),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TxFilterHeaderDelegate(
            selected: _filter,
            filters: _filters,
            onSelected: _onFilterSelected,
          ),
        ),
        if (state is TransactionLoading && !state.isPaginating)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state is TransactionError)
          SliverFillRemaining(
            child: Center(
              child: ErrorState(
                message: state.message,
                onRetry: () => context
                    .read<TransactionCubit>()
                    .load(filter: _apiFilter),
                compact: true,
              ),
            ),
          )
        else if (state is TransactionLoaded) ...[
          if (state.items.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: _filter == 'All' && _searchCtrl.text.trim().isEmpty
                    ? 'No transactions yet'
                    : 'No matches',
                message: _filter == 'All' &&
                        _searchCtrl.text.trim().isEmpty
                    ? 'Tap + to add one, or link a bank from Profile.'
                    : 'Clear search or choose All to see more.',
                actionLabel:
                    _filter == 'All' && _searchCtrl.text.trim().isEmpty
                        ? 'Add transaction'
                        : null,
                onAction: _filter == 'All' &&
                        _searchCtrl.text.trim().isEmpty
                    ? () => context.push(MintflowRoutes.addTx)
                    : null,
              ),
            )
          else
            ..._buildGroupedSlivers(state.items, selectable: selectable),
          if (state.hasMore || state.isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Material(
                  color: MintflowColors.card(context),
                  borderRadius: MintflowRadius.lg_,
                  child: Semantics(
                    button: true,
                    enabled: !state.isLoadingMore,
                    label: state.isLoadingMore
                        ? 'Loading more transactions'
                        : 'Load more transactions',
                    child: InkWell(
                      borderRadius: MintflowRadius.lg_,
                      onTap: state.isLoadingMore
                          ? null
                          : () => context.read<TransactionCubit>().loadMore(),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: MintflowRadius.lg_,
                          border: Border.all(
                              color: MintflowColors.hairline(context)),
                        ),
                        child: state.isLoadingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: MintflowColors.green400,
                                ),
                              )
                            : Text(
                                'Load more',
                                style: MintflowTextStyles.labelMedium.copyWith(
                                  color: MintflowColors.green600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  List<Widget> _buildGroupedSlivers(List<TransactionModel> items,
      {required bool selectable}) {
    final groups = _groupByDate(items);
    final keys = groups.keys.toList();
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
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
                  color: MintflowColors.softFill(context),
                  child: Text(key,
                      style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.textSecondary(context),
                          fontWeight: FontWeight.w500)),
                ),
                ...txs.asMap().entries.map((e) {
                  final tx = e.value;
                  final isLast = e.key == txs.length - 1;
                  return Column(
                    key: ValueKey(tx.id),
                    children: [
                      _TxRow(
                        tx: tx,
                        selected: selectable && tx.id == _selectedId,
                        onTap: selectable
                            ? () => setState(() => _selectedId = tx.id)
                            : null,
                      ),
                      if (!isLast)
                        Divider(
                            height: 1,
                            indent: 72,
                            color: MintflowColors.hairline(context)),
                    ],
                  );
                }),
              ],
            );
          },
          childCount: keys.length,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final expanded = MintBreakpoints.isExpanded(context);

    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        buildWhen: (prev, next) => prev != next,
        builder: (context, state) {
          if (!expanded) {
            return _listSlivers(context, state, selectable: false);
          }

          final items =
              state is TransactionLoaded ? state.items : <TransactionModel>[];
          final selected = _findSelected(items);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _listSlivers(context, state, selectable: true),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: MintflowColors.hairline(context),
              ),
              Expanded(
                flex: 4,
                child: _TxDetailPane(tx: selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TxFilter {
  final String id;
  final String api;
  const _TxFilter({required this.id, required this.api});
}

/// Pinned filter strip — theme tokens so light/dark both stay readable.
class _TxFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String selected;
  final List<_TxFilter> filters;
  final ValueChanged<String> onSelected;

  _TxFilterHeaderDelegate({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  static const double _height = 56;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: MintflowColors.page(context),
      elevation: overlapsContent ? 0.5 : 0,
      shadowColor: MintflowColors.ink.withValues(alpha: 0.12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: MintflowColors.hairline(context)),
          ),
        ),
        child: _TxFilterTabs(
          selected: selected,
          filters: filters,
          onSelected: onSelected,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TxFilterHeaderDelegate oldDelegate) =>
      selected != oldDelegate.selected ||
      filters != oldDelegate.filters ||
      onSelected != oldDelegate.onSelected;
}

/// Underline text tabs with scroll + visible overflow disclosure ("More").
class _TxFilterTabs extends StatefulWidget {
  final String selected;
  final List<_TxFilter> filters;
  final ValueChanged<String> onSelected;

  const _TxFilterTabs({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  @override
  State<_TxFilterTabs> createState() => _TxFilterTabsState();
}

class _TxFilterTabsState extends State<_TxFilterTabs> {
  final _scroll = ScrollController();
  final _menuCtrl = MenuController();
  bool _overflow = false;
  bool _atStart = true;
  bool _atEnd = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncScrollAffordance);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollAffordance());
  }

  @override
  void didUpdateWidget(covariant _TxFilterTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollAffordance());
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncScrollAffordance);
    _scroll.dispose();
    super.dispose();
  }

  void _syncScrollAffordance() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final overflow = pos.maxScrollExtent > 1;
    final atStart = pos.pixels <= pos.minScrollExtent + 1;
    final atEnd = pos.pixels >= pos.maxScrollExtent - 1;
    if (overflow == _overflow && atStart == _atStart && atEnd == _atEnd) {
      return;
    }
    setState(() {
      _overflow = overflow;
      _atStart = atStart;
      _atEnd = atEnd;
    });
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(
      _scroll.position.minScrollExtent,
      _scroll.position.maxScrollExtent,
    );
    await _scroll.animateTo(
      target,
      duration: MintMotion.duration(
        context,
        const Duration(milliseconds: 280),
      ),
      curve: MintMotion.curve(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MintBreakpoints.pageGutter(context);
    final page = MintflowColors.page(context);

    return Semantics(
      container: true,
      label: 'Transaction filters',
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      _syncScrollAffordance();
                      return false;
                    },
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: gutter,
                        right: _overflow ? 8 : gutter,
                      ),
                      itemCount: widget.filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (context, i) {
                        final f = widget.filters[i];
                        return _TxUnderlineTab(
                          label: f.id,
                          selected: widget.selected == f.id,
                          onTap: () => widget.onSelected(f.id),
                        );
                      },
                    ),
                  ),
                  if (_overflow && !_atStart)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: gutter + 20,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                page,
                                page.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_overflow && !_atEnd)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                page.withValues(alpha: 0),
                                page,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_overflow) ...[
              if (!_atStart)
                IconButton(
                  tooltip: 'Previous filters',
                  onPressed: () => _scrollBy(-140),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
              MenuAnchor(
                controller: _menuCtrl,
                alignmentOffset: const Offset(0, 4),
                style: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    MintflowColors.card(context),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: MintflowRadius.lg_,
                      side: BorderSide(
                        color: MintflowColors.hairline(context),
                      ),
                    ),
                  ),
                ),
                menuChildren: [
                  for (final f in widget.filters)
                    MenuItemButton(
                      onPressed: () {
                        widget.onSelected(f.id);
                        _menuCtrl.close();
                      },
                      trailingIcon: widget.selected == f.id
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: MintflowColors.green600,
                            )
                          : null,
                      child: Text(
                        f.id,
                        style: MintflowTextStyles.labelMedium.copyWith(
                          color: MintflowColors.textPrimary(context),
                          fontWeight: widget.selected == f.id
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                builder: (context, controller, child) {
                  final hiddenHint = !_atEnd ? 'More filters' : 'All filters';
                  return Padding(
                    padding: EdgeInsets.only(right: gutter - 8),
                    child: Semantics(
                      button: true,
                      label: hiddenHint,
                      child: TextButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: MintflowColors.green600,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'More',
                              style: MintflowTextStyles.labelMedium.copyWith(
                                color: MintflowColors.green600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              controller.isOpen
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 20,
                              color: MintflowColors.green600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TxUnderlineTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TxUnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? MintflowColors.textPrimary(context)
        : MintflowColors.textSecondary(context);
    final duration = MintMotion.duration(
      context,
      const Duration(milliseconds: 200),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: MintflowRadius.md_,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: MintflowTextStyles.labelMedium.copyWith(
                    color: fg,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: duration,
                  curve: MintMotion.curve(context),
                  height: 3,
                  width: selected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: MintflowColors.green400,
                    borderRadius: MintflowRadius.pill_,
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

class _TxDetailPane extends StatelessWidget {
  final TransactionModel? tx;
  const _TxDetailPane({required this.tx});

  @override
  Widget build(BuildContext context) {
    if (tx == null) {
      return ColoredBox(
        color: MintflowColors.page(context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 40,
                    color: MintflowColors.textSecondary(context)),
                const SizedBox(height: 12),
                Text(
                  'Select a transaction',
                  style: MintflowTextStyles.labelLarge.copyWith(
                    color: MintflowColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a row from the list to see details.',
                  textAlign: TextAlign.center,
                  style: MintflowTextStyles.bodySmall.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isCC = tx!.isCreditCardPayment;
    return ColoredBox(
      color: MintflowColors.page(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        children: [
          Text(
            tx!.displayName,
            style: MintflowTextStyles.displaySmall.copyWith(
              color: MintflowColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tx!.isIncome
                ? '+${MintflowFormat.currency(tx!.amount)}'
                : isCC
                    ? MintflowFormat.currency(tx!.amount)
                    : '-${MintflowFormat.currency(tx!.amount)}',
            style: MintflowTextStyles.amountMedium.copyWith(
              color: tx!.isIncome
                  ? MintflowColors.green500
                  : MintflowColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 24),
          _DetailRow(
            label: 'Date',
            value: MintflowFormat.dateShort(tx!.date),
          ),
          _DetailRow(
            label: 'Category',
            value: isCC
                ? 'Credit card payment (not counted as spend)'
                : (tx!.category?.name ??
                    (tx!.isIncome ? 'Income' : 'Expense')),
          ),
          if (tx!.isNeed != null)
            _DetailRow(
              label: 'Need or want',
              value: tx!.isNeed! ? 'Need' : 'Want',
            ),
          _DetailRow(
            label: 'Source',
            value: tx!.source.name,
          ),
          if (tx!.aiCategorized)
            const _DetailRow(
              label: 'Categorization',
              value: 'Automatic',
            ),
          if (tx!.notes != null && tx!.notes!.trim().isNotEmpty)
            _DetailRow(label: 'Notes', value: tx!.notes!),
          if (tx!.description != null &&
              tx!.description!.trim().isNotEmpty &&
              tx!.description != tx!.displayName)
            _DetailRow(label: 'Description', value: tx!.description!),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MintflowTextStyles.labelMedium.copyWith(
              color: MintflowColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MintflowTextStyles.bodyLarge.copyWith(
              color: MintflowColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel tx;
  final bool selected;
  final VoidCallback? onTap;
  const _TxRow({required this.tx, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCC = tx.isCreditCardPayment;
    final row = Container(
      color: selected
          ? MintflowColors.mintWash(context)
          : MintflowColors.card(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCC
                ? MintflowColors.purpleWash(context)
                : tx.isIncome
                    ? MintflowColors.mintWash(context)
                    : MintflowColors.softFill(context),
            borderRadius: MintflowRadius.md_,
          ),
          child: Icon(
            isCC
                ? Icons.credit_card_outlined
                : tx.isIncome
                    ? Icons.trending_up
                    : Icons.receipt_long_outlined,
            size: 18,
            color: isCC
                ? MintflowColors.purple
                : tx.isIncome
                    ? MintflowColors.green500
                    : MintflowColors.textSecondary(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MintflowTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: MintflowColors.textPrimary(context))),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                  child: Text(
                    isCC
                        ? 'CC payment — excluded'
                        : (tx.category?.name ??
                            (tx.isIncome ? 'Income' : 'Expense')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCC
                        ? MintflowTextStyles.overline.copyWith(
                            color: MintflowColors.purple,
                            fontWeight: FontWeight.w500)
                        : MintflowTextStyles.overline.copyWith(
                            color: MintflowColors.textSecondary(context)),
                  ),
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
                ? '+${MintflowFormat.currency(tx.amount)}'
                : isCC
                    ? MintflowFormat.currency(tx.amount)
                    : '-${MintflowFormat.currency(tx.amount)}',
            style: MintflowTextStyles.labelLarge.copyWith(
              color: tx.isIncome
                  ? MintflowColors.green400
                  : isCC
                      ? MintflowColors.textSecondary(context)
                      : MintflowColors.textPrimary(context),
              fontSize: isCC ? 12 : 14,
            ),
          ),
          if (tx.aiCategorized)
            Row(children: [
              const Icon(Icons.auto_awesome,
                  size: 10, color: MintflowColors.green400),
              const SizedBox(width: 2),
              Text('Auto',
                  style: MintflowTextStyles.chip
                      .copyWith(color: MintflowColors.green400)),
            ]),
        ]),
      ]),
    );

    if (onTap == null) return row;

    return Semantics(
      button: true,
      selected: selected,
      label: tx.displayName,
      child: InkWell(onTap: onTap, child: row),
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
          color: isNeed ? MintflowColors.mintWash(context) : MintflowColors.wantWash(context),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isNeed ? 'need' : 'want',
          style: MintflowTextStyles.chip.copyWith(
            color: isNeed ? MintflowColors.green600 : MintflowColors.wantLabel(context),
          ),
        ),
      );
}
