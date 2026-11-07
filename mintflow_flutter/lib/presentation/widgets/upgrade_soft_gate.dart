import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/utils/revenuecat.dart';

/// Feature → tier + copy for soft-gate sheets.
class _UpgradeCopy {
  final String title;
  final String tier; // Growth | Pro
  final List<String> bullets;

  const _UpgradeCopy({
    required this.title,
    required this.tier,
    required this.bullets,
  });
}

const _browseCopy = _UpgradeCopy(
  title: 'Your plan',
  tier: 'Growth',
  bullets: [
    'Seed — free manual tracking',
    'Growth — bank sync + AI insights',
    'Pro — debt tools, OCR, CSV export',
  ],
);

const _featureCopy = <String, _UpgradeCopy>{
  'bank_sync': _UpgradeCopy(
    title: 'Bank sync needs Growth',
    tier: 'Growth',
    bullets: [
      'Connect accounts via Plaid (read-only)',
      'Auto-import transactions',
      'AI categorization after sync',
    ],
  ),
  'unlimited_accounts': _UpgradeCopy(
    title: 'More accounts need Pro',
    tier: 'Pro',
    bullets: [
      'Unlimited linked bank accounts',
      'Everything in Growth',
      'Debt tools and CSV export',
    ],
  ),
  'ai_insights': _UpgradeCopy(
    title: 'AI insights need Growth',
    tier: 'Growth',
    bullets: [
      'Monthly coaching insights',
      'Spending patterns that matter',
      'Bank sync + categorization',
    ],
  ),
  'ai_categorization': _UpgradeCopy(
    title: 'AI categorization needs Growth',
    tier: 'Growth',
    bullets: [
      'Auto-label merchants',
      'Needs vs wants',
      'Less manual cleanup',
    ],
  ),
  'subscription_tracker': _UpgradeCopy(
    title: 'Subscription tracking needs Growth',
    tier: 'Growth',
    bullets: [
      'Spot Netflix, Spotify, and similar charges',
      'See recurring spend in one place',
      'Tied to bank sync',
    ],
  ),
  'unlimited_bills': _UpgradeCopy(
    title: 'Unlimited bills need Growth',
    tier: 'Growth',
    bullets: [
      'Track every bill and due date',
      'Reminders before you’re late',
      'Works with bank sync',
    ],
  ),
  'unlimited_goals': _UpgradeCopy(
    title: 'Unlimited goals need Growth',
    tier: 'Growth',
    bullets: [
      'Save toward every target',
      'Progress you can see',
      'Pairs with monthly insights',
    ],
  ),
  'csv_export': _UpgradeCopy(
    title: 'CSV export needs Pro',
    tier: 'Pro',
    bullets: [
      'Download your transaction history',
      'Own your data anytime',
      'Includes Growth features',
    ],
  ),
  'debt_payoff_plan': _UpgradeCopy(
    title: 'Debt payoff plans need Pro',
    tier: 'Pro',
    bullets: [
      'Snowball or avalanche plans',
      'Clear payoff timeline',
      'Built for serious debt work',
    ],
  ),
  'receipt_ocr': _UpgradeCopy(
    title: 'Receipt scan needs Pro',
    tier: 'Pro',
    bullets: [
      'Capture receipts with OCR',
      'Less manual entry',
      'Pairs with custom categories',
    ],
  ),
  'credit_utilization': _UpgradeCopy(
    title: 'Credit utilization needs Pro',
    tier: 'Pro',
    bullets: [
      'Track card utilization',
      'Stay ahead of limits',
      'Part of the Pro toolkit',
    ],
  ),
};

_UpgradeCopy _copyFor(String? feature) {
  if (feature == null || feature.isEmpty) return _browseCopy;
  return _featureCopy[feature] ??
      const _UpgradeCopy(
        title: 'Upgrade to unlock this feature',
        tier: 'Growth',
        bullets: [
          'Growth unlocks bank sync and AI',
          'Pro adds debt tools and exports',
          'Cancel anytime after trial',
        ],
      );
}

String _paywallPath(String? feature) {
  if (feature == null || feature.isEmpty) return MintflowRoutes.paywall;
  return '${MintflowRoutes.paywall}?feature=$feature';
}

/// Opens a soft-gate / browse sheet for every paywall-bound journey.
///
/// When RevenueCat is not configured, does **not** navigate to an empty
/// paywall — shows unavailable copy and a clear exit instead.
Future<void> openUpgradeFlow(
  BuildContext context, {
  String? feature,
  bool replaceRoute = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MintflowColors.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _UpgradeSoftGateSheet(
      feature: feature,
      replaceRoute: replaceRoute,
    ),
  );
}

class _UpgradeSoftGateSheet extends StatefulWidget {
  final String? feature;
  final bool replaceRoute;

  const _UpgradeSoftGateSheet({
    required this.feature,
    required this.replaceRoute,
  });

  @override
  State<_UpgradeSoftGateSheet> createState() => _UpgradeSoftGateSheetState();
}

class _UpgradeSoftGateSheetState extends State<_UpgradeSoftGateSheet> {
  bool _restoring = false;

  _UpgradeCopy get _copy => _copyFor(widget.feature);

  bool get _rcReady => revenueCatConfigured;

  bool get _isBrowse =>
      widget.feature == null || widget.feature!.trim().isEmpty;

  Future<void> _seePlans() async {
    if (!_rcReady) return;
    final path = _paywallPath(widget.feature);
    final router = GoRouter.of(context);
    final replace = widget.replaceRoute;
    Navigator.of(context).pop();
    if (replace) {
      router.go(path);
    } else {
      router.push(path);
    }
  }

  Future<void> _exitUnavailable() async {
    final router = GoRouter.of(context);
    final replace = widget.replaceRoute;
    Navigator.of(context).pop();
    if (replace) {
      router.go(MintflowRoutes.dashboard);
    }
  }

  Future<void> _restore() async {
    if (!_rcReady || _restoring) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _restoring = true);
    try {
      await Purchases.restorePurchases();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Purchases restored.'),
          backgroundColor: MintflowColors.green500,
        ),
      );
      router.go(MintflowRoutes.dashboard);
    } on PlatformException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.message?.trim().isNotEmpty == true
                ? e.message!
                : 'Couldn’t restore purchases. Check your store account and try again.',
          ),
          backgroundColor: MintflowColors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn’t restore purchases. Check your store account and try again.',
          ),
          backgroundColor: MintflowColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gutter = MintBreakpoints.pageGutter(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintflowColors.hairline(context),
                  borderRadius: MintflowRadius.pill_,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _copy.title,
              style: MintflowTextStyles.displaySmall.copyWith(
                color: MintflowColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isBrowse
                  ? 'Choose Seed, Growth, or Pro when you’re ready.'
                  : 'Included on ${_copy.tier}. 7-day Pro trial — cancel anytime.',
              style: MintflowTextStyles.bodySmall.copyWith(
                color: MintflowColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            for (final bullet in _copy.bullets) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: MintflowColors.green500,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: MintflowTextStyles.bodySmall.copyWith(
                          color: MintflowColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!_rcReady) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintflowColors.goldWash(context),
                  borderRadius: MintflowRadius.lg_,
                  border: Border.all(color: MintflowColors.gold400),
                ),
                child: Text(
                  widget.replaceRoute
                      ? 'Upgrades aren’t available in this build yet. You can keep going with manual tracking and upgrade later.'
                      : 'Upgrades aren’t available right now. You can go back and keep using Flowra — try again later.',
                  style: MintflowTextStyles.bodySmall.copyWith(
                    color: MintflowColors.textPrimary(context),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_rcReady)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _restoring ? null : _seePlans,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    backgroundColor: MintflowColors.green400,
                    foregroundColor: MintflowColors.onMint(context),
                  ),
                  child: const Text('See plans'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _restoring ? null : _exitUnavailable,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                    backgroundColor: MintflowColors.green400,
                    foregroundColor: MintflowColors.onMint(context),
                  ),
                  child: Text(
                    widget.replaceRoute ? 'Continue to app' : 'Go back',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _restoring
                  ? null
                  : () {
                      final router = GoRouter.of(context);
                      final replace = widget.replaceRoute;
                      Navigator.of(context).pop();
                      if (replace) {
                        router.go(MintflowRoutes.dashboard);
                      }
                    },
              child: Text(
                _rcReady
                    ? 'Not now'
                    : (widget.replaceRoute ? 'Not now' : 'Dismiss'),
              ),
            ),
            if (_rcReady) ...[
              TextButton(
                onPressed: _restoring ? null : _restore,
                style: TextButton.styleFrom(
                  foregroundColor: MintflowColors.textSecondary(context),
                ),
                child: _restoring
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MintflowColors.textSecondary(context),
                        ),
                      )
                    : const Text('Restore purchases'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
