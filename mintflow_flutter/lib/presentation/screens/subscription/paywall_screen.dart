import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/revenuecat.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paywall Screen — RevenueCat offerings + purchase / restore
// Route: /paywall?feature=
// ─────────────────────────────────────────────────────────────────────────────

class PaywallScreen extends StatefulWidget {
  final String? feature;
  const PaywallScreen({super.key, this.feature});
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selected = 'growth';
  bool _annual = false;
  bool _loading = true;
  bool _purchasing = false;
  bool _rcConfigured = false;
  String? _error;
  Offerings? _offerings;

  final _plans = const [
    _Plan(
      id: 'seed',
      name: 'Seed',
      monthlyPrice: 0,
      annualPrice: 0,
      sub: 'Free forever',
      features: [
        'Manual transaction entry',
        'Up to 50 transactions/month',
        'Monthly spending target',
        'Basic monthly summary',
        'Core notifications',
        '1 savings goal',
        '3 bills to track',
      ],
      highlighted: false,
    ),
    _Plan(
      id: 'growth',
      name: 'Growth',
      monthlyPrice: 6.99,
      annualPrice: 59,
      sub: 'Most popular',
      features: [
        'Everything in Seed',
        'Bank sync via Plaid',
        'AI auto-categorization',
        'Needs vs wants',
        'Unlimited savings goals',
        'Unlimited bill tracker',
        'Monthly AI insights',
        'Spending trends',
        'Category budgets',
      ],
      highlighted: true,
    ),
    _Plan(
      id: 'pro',
      name: 'Pro',
      monthlyPrice: 12.99,
      annualPrice: 99,
      sub: 'For the financially serious',
      features: [
        'Everything in Growth',
        'Unlimited bank accounts',
        'AI debt payoff plan',
        'Credit utilization tracking',
        'Receipt scan (OCR)',
        'Custom categories',
        'CSV data export',
        'Rollover budgets',
      ],
      highlighted: false,
    ),
  ];

  static const _featureCopy = {
    'bank_sync': 'Connect your bank with Growth or Pro.',
    'ai_insights': 'Unlock monthly AI insights on Growth or Pro.',
    'ai_categorization': 'AI categorization requires Growth or Pro.',
    'subscription_tracker':
        'Track Netflix, Spotify, and other recurring charges on Growth or Pro.',
    'unlimited_bills': 'Unlimited bills require Growth or Pro.',
    'debt_payoff_plan': 'Debt payoff plans are a Pro feature.',
    'receipt_ocr': 'Receipt scanning is available on Pro.',
    'csv_export': 'CSV export requires Pro.',
    'unlimited_accounts': 'Unlimited accounts require Pro.',
  };

  @override
  void initState() {
    super.initState();
    if (widget.feature == 'debt_payoff_plan' ||
        widget.feature == 'receipt_ocr' ||
        widget.feature == 'csv_export' ||
        widget.feature == 'unlimited_accounts' ||
        widget.feature == 'credit_utilization') {
      _selected = 'pro';
    }
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!revenueCatConfigured) {
      if (!mounted) return;
      setState(() {
        _rcConfigured = false;
        _loading = false;
        _error =
            'Subscriptions aren’t available in this build yet. Try again later.';
      });
      return;
    }
    try {
      final offerings = await Purchases.getOfferings();
      if (!mounted) return;
      setState(() {
        _offerings = offerings;
        _rcConfigured = true;
        _loading = false;
      });
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() {
        _rcConfigured = false;
        _loading = false;
        _error =
            'Couldn’t load plans from the App Store or Google Play. Try again shortly.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rcConfigured = false;
        _loading = false;
        _error =
            'Couldn’t load subscription plans. Check your connection and try again.';
      });
    }
  }

  Package? _packageFor(String planId) {
    final offering = _offerings?.current;
    if (offering == null) return null;
    final packages = offering.availablePackages;
    final wantAnnual = _annual;
    for (final p in packages) {
      final id = p.identifier.toLowerCase();
      final productId = p.storeProduct.identifier.toLowerCase();
      final matchesTier =
          id.contains(planId) || productId.contains(planId);
      final matchesPeriod = wantAnnual
          ? (p.packageType == PackageType.annual ||
              id.contains('annual') ||
              id.contains('year'))
          : (p.packageType == PackageType.monthly ||
              id.contains('month'));
      if (matchesTier && matchesPeriod) return p;
    }
    // Fallback: first package matching tier
    for (final p in packages) {
      final id = p.identifier.toLowerCase();
      final productId = p.storeProduct.identifier.toLowerCase();
      if (id.contains(planId) || productId.contains(planId)) return p;
    }
    return null;
  }

  Future<void> _purchase() async {
    if (_purchasing) return;
    if (_selected == 'seed') {
      context.pop();
      return;
    }
    if (!_rcConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _error ??
                'Purchases aren’t available right now. Try again later.',
          ),
          backgroundColor: MintflowColors.red,
        ),
      );
      return;
    }
    final package = _packageFor(_selected);
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This plan isn’t ready to buy yet. Pick another plan or try again later.',
          ),
          backgroundColor: MintflowColors.green900,
        ),
      );
      return;
    }
    setState(() => _purchasing = true);
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You’re subscribed. Welcome aboard.'),
            backgroundColor: MintflowColors.green500,
          ),
        );
        context.go(MintflowRoutes.dashboard);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message?.trim().isNotEmpty == true
                  ? e.message!
                  : 'Purchase didn’t finish. Try again.',
            ),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase didn’t finish. Try again.'),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    if (_purchasing) return;
    if (!_rcConfigured || !revenueCatConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _error ??
                'Purchases aren’t available right now. Try again later.',
          ),
          backgroundColor: MintflowColors.red,
        ),
      );
      return;
    }
    setState(() => _purchasing = true);
    try {
      await Purchases.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored.'),
            backgroundColor: MintflowColors.green500,
          ),
        );
        context.go(MintflowRoutes.dashboard);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Couldn’t restore purchases. Check your store account and try again.',
            ),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  _Plan get _selectedPlan => _plans.firstWhere((p) => p.id == _selected);

  String _priceLabel(_Plan p) {
    if (p.monthlyPrice == 0) return 'Free';
    final pkg = _packageFor(p.id);
    if (pkg != null) return pkg.storeProduct.priceString;
    if (_annual) return '\$${p.annualPrice}/yr';
    return '\$${p.monthlyPrice}/mo';
  }

  String get _featureHeadline {
    final f = widget.feature;
    if (f == null || f.isEmpty) return 'Unlock your full financial picture';
    return _featureCopy[f] ?? 'Upgrade to unlock this feature';
  }

  Widget _planTile(_Plan plan) {
    return Material(
      color: Colors.transparent,
      borderRadius: MintflowRadius.xl_,
      child: InkWell(
        borderRadius: MintflowRadius.xl_,
        onTap: _purchasing ? null : () => setState(() => _selected = plan.id),
        child: Semantics(
          button: true,
          selected: _selected == plan.id,
          label: '${plan.name} plan, ${_priceLabel(plan)}',
          child: _PlanCard(
            plan: plan,
            selected: _selected == plan.id,
            price: _priceLabel(plan),
            annual: _annual,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MintBreakpoints.pageGutter(context);
    // 3-up only at expanded — medium widths crush plan columns.
    final multiCol = MintBreakpoints.isExpanded(context);

    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: MintflowColors.green900,
          foregroundColor: MintflowColors.onBrand(context),
          leading: IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close, color: MintflowColors.onBrand(context)),
            onPressed: () => context.pop(),
          ),
        ),
        SliverToBoxAdapter(
          child: ColoredBox(
            color: MintflowColors.green900,
            child: MintAdaptiveWidth(
              maxWidth: MintBreakpoints.contentMax,
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _featureHeadline,
                      style: MintflowTextStyles.displaySmall
                          .copyWith(color: MintflowColors.cream),
                    ),
                    if (widget.feature == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '7-day Pro trial — cancel anytime',
                        style: MintflowTextStyles.bodySmall.copyWith(
                          color: MintflowColors.onBrandMuted(context, 0.5),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MintAdaptiveWidth(
            maxWidth: MintBreakpoints.contentMax,
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    if (!_rcConfigured && _error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: MintflowColors.goldWash(context),
                          borderRadius: MintflowRadius.lg_,
                          border: Border.all(color: MintflowColors.gold400),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: MintflowTextStyles.bodySmall.copyWith(
                                  color: MintflowColors.textPrimary(context)),
                            ),
                            if (revenueCatConfigured) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _purchasing ? null : _loadOfferings,
                                style: TextButton.styleFrom(
                                  foregroundColor: MintflowColors.green600,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(48, 48),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Try again'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Billing period group
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Monthly'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Annual'),
                            tooltip: 'Save 30% vs monthly',
                          ),
                        ],
                        selected: {_annual},
                        onSelectionChanged: _purchasing
                            ? null
                            : (selection) {
                                setState(() => _annual = selection.first);
                              },
                        showSelectedIcon: false,
                      ),
                    ),
                    if (_annual) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Save 30% with annual billing',
                        style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.green500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Plan comparison group
                    if (multiCol)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _plans.length; i++) ...[
                            if (i > 0) const SizedBox(width: 12),
                            Expanded(child: _planTile(_plans[i])),
                          ],
                        ],
                      )
                    else
                      ...[
                        for (var i = 0; i < _plans.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == _plans.length - 1 ? 0 : 12,
                            ),
                            child: _planTile(_plans[i]),
                          ),
                      ],
                    // Clear sticky CTA cluster (button + restore + legal).
                    const SizedBox(height: 160),
                  ],
                ],
              ),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: _loading
          ? null
          : Material(
              color: MintflowColors.page(context),
              elevation: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: MintflowColors.hairline(context)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: MintAdaptiveWidth(
                    maxWidth: MintBreakpoints.formMax,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _purchasing ? null : _purchase,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(48, 52),
                                backgroundColor: MintflowColors.green400,
                                foregroundColor: MintflowColors.onMint(context),
                              ),
                              child: _purchasing
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: MintflowColors.onMint(context),
                                      ),
                                    )
                                  : Text(
                                      _selected == 'seed'
                                          ? 'Continue with free'
                                          : _selected == 'growth'
                                              ? 'Start Growth — ${_priceLabel(_selectedPlan)}'
                                              : 'Start Pro — ${_priceLabel(_selectedPlan)}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: (_purchasing || !_rcConfigured)
                                ? null
                                : _restore,
                            child: const Text('Restore purchases'),
                          ),
                          Text(
                            'Cancel anytime. Billed ${_annual ? "annually" : "monthly"}. '
                            'Apple/Google manage payments. No hidden fees.',
                            textAlign: TextAlign.center,
                            style: MintflowTextStyles.overline.copyWith(
                              color: MintflowColors.textSecondary(context),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected, annual;
  final String price;
  const _PlanCard(
      {required this.plan,
      required this.selected,
      required this.price,
      required this.annual});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MintMotion.duration(
        context,
        const Duration(milliseconds: 200),
      ),
      curve: MintMotion.curve(context),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        borderRadius: MintflowRadius.xl_,
        border: Border.all(
          color: selected
              ? MintflowColors.green400
              : MintflowColors.hairline(context),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MintflowTextStyles.labelLarge.copyWith(
                        color: MintflowColors.textPrimary(context)),
                  ),
                ),
                if (plan.highlighted) ...[
                  const SizedBox(width: 8),
                  Text('Popular',
                      style: MintflowTextStyles.chip.copyWith(
                          color: MintflowColors.green600,
                          fontWeight: FontWeight.w600)),
                ],
              ]),
              Text(
                plan.sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textSecondary(context)),
              ),
            ],
          )),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: MintflowTextStyles.amountSmall.copyWith(
                      color: MintflowColors.textPrimary(context), fontSize: 18),
                ),
                if (annual && plan.monthlyPrice > 0)
                  Text(
                    '(\$${(plan.annualPrice / 12).toStringAsFixed(2)}/mo)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.textSecondary(context)),
                  ),
              ],
            ),
          ),
        ]),
        AnimatedSize(
          duration: MintMotion.duration(
            context,
            const Duration(milliseconds: 250),
          ),
          curve: MintMotion.curve(context),
          child: selected
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: plan.features
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check,
                                      size: 14, color: MintflowColors.green400),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(f,
                                          style: MintflowTextStyles.bodySmall
                                              .copyWith(
                                                  color: MintflowColors
                                                      .textSecondary(context),
                                                  height: 1.4))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _Plan {
  final String id, name, sub;
  final double monthlyPrice, annualPrice;
  final List<String> features;
  final bool highlighted;
  const _Plan(
      {required this.id,
      required this.name,
      required this.sub,
      required this.monthlyPrice,
      required this.annualPrice,
      required this.features,
      required this.highlighted});
}
