import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!revenueCatConfigured) {
      setState(() {
        _rcConfigured = false;
        _loading = false;
        _error =
            'RevenueCat is not configured. Set REVENUECAT_API_KEY to enable purchases.';
      });
      return;
    }
    try {
      final offerings = await Purchases.getOfferings();
      setState(() {
        _offerings = offerings;
        _rcConfigured = true;
        _loading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _rcConfigured = false;
        _loading = false;
        _error = e.message ??
            'Subscriptions are not configured yet. Add REVENUECAT_API_KEY.';
      });
    } catch (e) {
      setState(() {
        _rcConfigured = false;
        _loading = false;
        _error =
            'RevenueCat is not configured. Set REVENUECAT_API_KEY to enable purchases.';
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
    if (_selected == 'seed') {
      context.pop();
      return;
    }
    if (!_rcConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Purchases unavailable'),
          backgroundColor: FlowraColors.red,
        ),
      );
      return;
    }
    final package = _packageFor(_selected);
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No store package found for this plan yet.'),
          backgroundColor: FlowraColors.gold500,
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
            content: Text('Welcome aboard — subscription active.'),
            backgroundColor: FlowraColors.green500,
          ),
        );
        context.go(FlowraRoutes.dashboard);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Purchase failed'),
            backgroundColor: FlowraColors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: FlowraColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _restore() async {
    if (!_rcConfigured || !revenueCatConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Purchases unavailable'),
          backgroundColor: FlowraColors.red,
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
            backgroundColor: FlowraColors.green500,
          ),
        );
        context.go(FlowraRoutes.dashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: FlowraColors.red,
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
    return _featureCopy[f] ?? 'Upgrade to unlock $f';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: FlowraColors.green900,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('UPGRADE FLOWRA',
                        style: FlowraTextStyles.overline.copyWith(
                            color: FlowraColors.cream.withOpacity(0.5))),
                    const SizedBox(height: 4),
                    Text(_featureHeadline,
                        style: FlowraTextStyles.displaySmall
                            .copyWith(color: FlowraColors.cream)),
                    const SizedBox(height: 8),
                    Text(
                      widget.feature != null
                          ? 'Feature: ${widget.feature}'
                          : '7-day Pro trial available — no card required',
                      style: FlowraTextStyles.bodySmall.copyWith(
                          color: FlowraColors.cream.withOpacity(0.5),
                          fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
            ),
          ),
          expandedHeight: 180,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )
              else ...[
                if (!_rcConfigured && _error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FlowraColors.gold50,
                      borderRadius: FlowraRadius.lg_,
                      border: Border.all(color: FlowraColors.gold400),
                    ),
                    child: Text(
                      _error!,
                      style: FlowraTextStyles.bodySmall
                          .copyWith(color: FlowraColors.ink),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: FlowraColors.creamDark,
                    borderRadius: FlowraRadius.lg_,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(children: [
                    Expanded(
                        child: GestureDetector(
                      onTap: () => setState(() => _annual = false),
                      child: _BillingTab(
                          label: 'Monthly', active: !_annual, badge: null),
                    )),
                    Expanded(
                        child: GestureDetector(
                      onTap: () => setState(() => _annual = true),
                      child: _BillingTab(
                          label: 'Annual',
                          active: _annual,
                          badge: 'Save 30%'),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
                ..._plans.map((plan) => GestureDetector(
                      onTap: () => setState(() => _selected = plan.id),
                      child: _PlanCard(
                        plan: plan,
                        selected: _selected == plan.id,
                        price: _priceLabel(plan),
                        annual: _annual,
                      ),
                    )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _purchasing ? null : _purchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selected == 'growth'
                          ? FlowraColors.purple
                          : FlowraColors.green400,
                    ),
                    child: _purchasing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _selected == 'seed'
                                ? 'Continue with free'
                                : _selected == 'growth'
                                    ? 'Start Growth — ${_priceLabel(_selectedPlan)}'
                                    : 'Start Pro — ${_priceLabel(_selectedPlan)}',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: (_purchasing || !_rcConfigured) ? null : _restore,
                  child: const Text('Restore purchases'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cancel anytime. Billed ${_annual ? "annually" : "monthly"}. '
                  'Apple/Google manage payments. No hidden fees.',
                  textAlign: TextAlign.center,
                  style: FlowraTextStyles.overline.copyWith(
                      color: FlowraColors.ink60, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 60),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _BillingTab extends StatelessWidget {
  final String label;
  final bool active;
  final String? badge;
  const _BillingTab({required this.label, required this.active, this.badge});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: FlowraRadius.md_,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              textAlign: TextAlign.center,
              style: FlowraTextStyles.labelMedium.copyWith(
                  color: active ? FlowraColors.ink : FlowraColors.ink60)),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FlowraColors.green400,
                borderRadius: FlowraRadius.pill_,
              ),
              child: Text(badge!,
                  style: FlowraTextStyles.overline
                      .copyWith(color: Colors.white, fontSize: 9)),
            ),
          ],
        ]),
      );
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
    final Color borderColor = selected
        ? (plan.highlighted ? FlowraColors.purple : FlowraColors.green400)
        : FlowraColors.ink10;
    final Color bgColor =
        selected && plan.highlighted ? FlowraColors.purpleSoft : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: FlowraRadius.xl_,
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(plan.name,
                    style: FlowraTextStyles.labelLarge.copyWith(
                        color: plan.highlighted && selected
                            ? FlowraColors.purple
                            : FlowraColors.ink)),
                if (plan.highlighted) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FlowraColors.purple,
                      borderRadius: FlowraRadius.pill_,
                    ),
                    child: Text('Most popular',
                        style: FlowraTextStyles.overline
                            .copyWith(color: Colors.white)),
                  ),
                ],
              ]),
              Text(plan.sub,
                  style: FlowraTextStyles.overline.copyWith(
                      color: plan.highlighted && selected
                          ? FlowraColors.purple.withOpacity(0.7)
                          : FlowraColors.ink60)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price,
                style: FlowraTextStyles.amountSmall.copyWith(
                    color: plan.highlighted && selected
                        ? FlowraColors.purple
                        : FlowraColors.ink,
                    fontSize: 18)),
            if (annual && plan.monthlyPrice > 0)
              Text('(\$${(plan.annualPrice / 12).toStringAsFixed(2)}/mo)',
                  style: FlowraTextStyles.overline
                      .copyWith(color: FlowraColors.ink60)),
          ]),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: selected
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: plan.features
                        .map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check,
                                      size: 14,
                                      color: plan.highlighted
                                          ? FlowraColors.purple
                                          : FlowraColors.green400),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(f,
                                          style: FlowraTextStyles.bodySmall
                                              .copyWith(
                                                  color: FlowraColors.ink60,
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
