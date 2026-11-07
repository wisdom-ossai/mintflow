import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/theme/mint_inputs.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../core/utils/revenuecat.dart';
import '../../../data/datasources/service_locator.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';
import '../../widgets/upgrade_soft_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen — 3-step wizard
// Step 1: Welcome + name (pre-filled from signup)
// Step 2: Income + spending target
// Step 3: Connect bank or go manual
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _loading = false;
  StreamSubscription<LinkSuccess>? _plaidSuccessSub;
  StreamSubscription<LinkExit>? _plaidExitSub;

  final _nameCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _email = '';

  @override
  void initState() {
    super.initState();
    _prefillFromUser();
  }

  Future<void> _prefillFromUser() async {
    final cubit = context.read<UserCubit>();
    var state = cubit.state;
    if (state is! UserLoaded) {
      await cubit.load(forceRefresh: true);
      if (!mounted) return;
      state = cubit.state;
    }
    if (state is UserLoaded) {
      final user = state.user;
      setState(() {
        if (_nameCtrl.text.isEmpty &&
            user.fullName != null &&
            user.fullName!.trim().isNotEmpty) {
          _nameCtrl.text = user.fullName!.trim();
        }
        _email = user.email;
      });
    } else {
      try {
        final me = await ServiceLocator.instance.api.getAuthMe();
        if (!mounted) return;
        setState(() {
          if (_nameCtrl.text.isEmpty &&
              me.fullName != null &&
              me.fullName!.trim().isNotEmpty) {
            _nameCtrl.text = me.fullName!.trim();
          }
          _email = me.email;
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _plaidSuccessSub?.cancel();
    _plaidExitSub?.cancel();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _incomeCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    if (MintMotion.reduce(context)) {
      _pageCtrl.jumpToPage(step);
      return;
    }
    _pageCtrl.animateToPage(
      step,
      duration: MintMotion.duration(
        context,
        const Duration(milliseconds: 300),
      ),
      curve: MintMotion.curve(context),
    );
  }

  void _next() {
    if (_step < 2) _goToStep(_step + 1);
  }

  void _back() {
    if (_step > 0) _goToStep(_step - 1);
  }

  Future<UserModel?> _submitOnboarding() async {
    final income = double.tryParse(_incomeCtrl.text.replaceAll(',', ''));
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', ''));
    final name = _nameCtrl.text.trim();
    return context.read<UserCubit>().completeOnboarding({
      if (name.isNotEmpty) 'full_name': name,
      if (income != null) 'monthly_income': income,
      if (target != null) 'monthly_spending_target': target,
    });
  }

  Future<void> _finishManual() async {
    setState(() => _loading = true);
    try {
      await _submitOnboarding();
      // User explicitly chose manual setup on step 3; complete onboarding flow.
      AuthGate.setOnboardingComplete(true);
      if (mounted) context.go(MintflowRoutes.dashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyAuthError(e)),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectBank() async {
    setState(() => _loading = true);
    try {
      final user = await _submitOnboarding();
      if (!mounted) return;

      final current = user ??
          (context.read<UserCubit>().state is UserLoaded
              ? (context.read<UserCubit>().state as UserLoaded).user
              : null);

      if (current == null || !current.hasFeature('bank_sync')) {
        AuthGate.setOnboardingComplete(
            current?.hasCompletedOnboarding ??
                _nameCtrl.text.trim().isNotEmpty);
        if (mounted) setState(() => _loading = false);
        if (!revenueCatConfigured) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Bank sync needs Growth. Upgrades aren’t available in this build yet — you can link a bank later from Profile.',
                ),
                backgroundColor: MintflowColors.green900,
              ),
            );
            context.go(MintflowRoutes.dashboard);
          }
          return;
        }
        await openUpgradeFlow(
          context,
          feature: 'bank_sync',
          replaceRoute: true,
        );
        return;
      }

      final tokenRes = await ServiceLocator.instance.api.getPlaidLinkToken();
      final linkToken = tokenRes['link_token'] as String?;
      if (linkToken == null || linkToken.isEmpty) {
        throw Exception('Missing link token');
      }

      await _plaidSuccessSub?.cancel();
      await _plaidExitSub?.cancel();

      _plaidSuccessSub = PlaidLink.onSuccess.listen((success) async {
        try {
          await ServiceLocator.instance.api.exchangePlaidToken(
            success.publicToken,
            institutionName: success.metadata.institution?.name,
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Bank connected, but Mintflow couldn’t sync yet. Open Linked accounts later to retry.',
                ),
                backgroundColor: MintflowColors.green900,
              ),
            );
          }
        }
        AuthGate.setOnboardingComplete(true);
        if (mounted) context.go(MintflowRoutes.dashboard);
      });

      _plaidExitSub = PlaidLink.onExit.listen((exit) {
        if (mounted) {
          setState(() => _loading = false);
          final raw = exit.error?.displayMessage ?? exit.error?.message;
          final msg = (raw != null && raw.trim().isNotEmpty)
              ? raw.trim()
              : 'Bank connection canceled.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: MintflowColors.textSecondary(context)),
          );
        }
      });

      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: linkToken),
      );
      await PlaidLink.open();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Couldn’t open bank link. Check your connection and try again.',
            ),
            backgroundColor: MintflowColors.red,
          ),
        );
      }
    }
  }

  void _suggestTarget() {
    final income = double.tryParse(_incomeCtrl.text.replaceAll(',', ''));
    if (income != null && income > 0) {
      final suggested = (income * 0.7).round();
      _targetCtrl.text = suggested.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: Column(children: [
        _OnboardingHeader(step: _step, onBack: _step > 0 ? _back : null),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Step1Welcome(
                nameCtrl: _nameCtrl,
                email: _email,
                onNext: _next,
              ),
              _Step2Target(
                incomeCtrl: _incomeCtrl,
                targetCtrl: _targetCtrl,
                onIncomeChanged: _suggestTarget,
                onNext: _next,
              ),
              _Step3Connect(
                loading: _loading,
                onConnectBank: _connectBank,
                onManual: _finishManual,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _OnboardingHeader extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  const _OnboardingHeader({required this.step, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MintflowColors.green900,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
          child: Column(children: [
            Row(children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back,
                      color: MintflowColors.cream, size: 20),
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              // Step dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final active = i == step;
                  final done = i < step;
                  return AnimatedContainer(
                    duration: MintMotion.duration(
                      context,
                      const Duration(milliseconds: 250),
                    ),
                    curve: MintMotion.curve(context),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? MintflowColors.green400
                          : done
                              ? MintflowColors.green400.withValues(alpha: 0.5)
                              : MintflowColors.brandOverlay(context, 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  AuthGate.setOnboardingComplete(true);
                  context.go(MintflowRoutes.dashboard);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: MintflowColors.onBrandMuted(context, 0.5),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Text(
                  'Skip',
                  semanticsLabel: 'Skip onboarding',
                  style: MintflowTextStyles.labelSmall.copyWith(
                    color: MintflowColors.onBrandMuted(context, 0.5),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String title, subtitle;
  const _StepHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MintflowTextStyles.displaySmall
                  .copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: MintflowTextStyles.bodyMedium
                  .copyWith(color: MintflowColors.textSecondary(context))),
        ],
      );
}

class _NextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const _NextButton(
      {required this.label, this.onPressed, this.loading = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: MintflowColors.cream, strokeWidth: 2))
              : Text(label),
        ),
      );
}

// ── Step 1 — Welcome + name ───────────────────────────────────────────────────

class _Step1Welcome extends StatelessWidget {
  final TextEditingController nameCtrl;
  final String email;
  final VoidCallback onNext;
  const _Step1Welcome({
    required this.nameCtrl,
    required this.email,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MintBreakpoints.pageGutter(context),
        24,
        MintBreakpoints.pageGutter(context),
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: MintAdaptiveWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const _StepHeader(
          title: 'Welcome to\nMintflow',
          subtitle: '7 days free — no card needed.',
        ),
        const SizedBox(height: 28),

        // Trial badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintflowColors.mintWash(context),
            borderRadius: MintflowRadius.lg_,
            border: Border.all(color: MintflowColors.green100),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: MintflowColors.green400),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: RichText(
              text: TextSpan(
                style: MintflowTextStyles.bodySmall
                    .copyWith(color: MintflowColors.green600, height: 1.5),
                children: const [
                  TextSpan(
                      text: '7-day Pro trial active. ',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  TextSpan(
                      text: 'All features unlocked. '
                          'Upgrade or drop to free after.'),
                ],
              ),
            )),
          ]),
        ),
        const SizedBox(height: 28),

        TextFormField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: mintInputDecoration(
            context,
            label: 'Your name',
            hint: 'Alex Johnson',
          ),
        ),
        const SizedBox(height: 12),

        Semantics(
          label: 'Email, ${email.isNotEmpty ? email : 'loading'}',
          child: InputDecorator(
            decoration: mintInputDecoration(
              context,
              label: 'Email',
              fillColor: MintflowColors.softFill(context),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline,
                  size: 16, color: MintflowColors.textSecondary(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  email.isNotEmpty ? email : 'Loading…',
                  style: MintflowTextStyles.bodyMedium.copyWith(
                      color: MintflowColors.textSecondary(context)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 36),
        _NextButton(label: 'Continue', onPressed: onNext),
      ]),
      ),
    );
  }
}

// ── Step 2 — Income + target ──────────────────────────────────────────────────

class _Step2Target extends StatelessWidget {
  final TextEditingController incomeCtrl, targetCtrl;
  final VoidCallback onIncomeChanged, onNext;
  const _Step2Target({
    required this.incomeCtrl,
    required this.targetCtrl,
    required this.onIncomeChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MintBreakpoints.pageGutter(context),
        24,
        MintBreakpoints.pageGutter(context),
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: MintAdaptiveWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const _StepHeader(
          title: 'Set your\nspending target',
          subtitle: "We'll track this every month.",
        ),
        const SizedBox(height: 28),

        TextFormField(
          controller: incomeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => onIncomeChanged(),
          decoration: mintInputDecoration(
            context,
            label: 'Monthly income (optional)',
            hint: '5,000',
          ).copyWith(prefixText: '\$ '),
        ),
        const SizedBox(height: 20),

        TextFormField(
          controller: targetCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: mintInputDecoration(
            context,
            label: 'Monthly spending target',
            hint: '3,500',
          ).copyWith(prefixText: '\$ '),
        ),
        const SizedBox(height: 12),

        // AI suggestion chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MintflowColors.card(context),
            borderRadius: MintflowRadius.md_,
            border: Border.all(color: MintflowColors.green100),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome,
                size: 14, color: MintflowColors.green500),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Mintflow suggests 70% of income as a starting target.',
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.green600),
            )),
          ]),
        ),
        const SizedBox(height: 36),

        _NextButton(label: 'Set my target', onPressed: onNext),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text('Skip for now'),
          ),
        ),
      ]),
      ),
    );
  }
}

// ── Step 3 — Connect bank (optional) ─────────────────────────────────────────

class _Step3Connect extends StatelessWidget {
  final bool loading;
  final VoidCallback onConnectBank, onManual;
  const _Step3Connect({
    required this.loading,
    required this.onConnectBank,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MintBreakpoints.pageGutter(context),
        24,
        MintBreakpoints.pageGutter(context),
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: MintAdaptiveWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const _StepHeader(
          title: 'See where your\nmoney goes',
          subtitle:
              'Connect a bank to import transactions automatically — or skip and add them by hand. You can connect anytime from Profile.',
        ),
        const SizedBox(height: 28),

        // Plaid option — recommended
        Semantics(
          button: true,
          label: 'Connect bank or card',
          child: InkWell(
          onTap: loading ? null : onConnectBank,
          borderRadius: MintflowRadius.xl_,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintflowColors.card(context),
              borderRadius: MintflowRadius.xl_,
              border: Border.all(color: MintflowColors.green400, width: 1.5),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: MintflowColors.green400,
                    borderRadius: MintflowRadius.md_,
                  ),
                  child: Icon(Icons.account_balance_outlined,
                      color: MintflowColors.onBrand(context), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connect bank or card',
                        style: MintflowTextStyles.labelMedium.copyWith(
                          color: MintflowColors.textPrimary(context),
                          fontWeight: FontWeight.w500,
                        )),
                    Text('Unlock auto-sync & AI categorization',
                        style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.textSecondary(context),
                        )),
                  ],
                )),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MintflowColors.mintWash(context),
                    borderRadius: MintflowRadius.pill_,
                  ),
                  child: Text('Optional',
                      style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.green600,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                'Your credentials never touch Mintflow — Plaid handles the '
                'secure connection. Read-only access only.',
                style: MintflowTextStyles.bodySmall
                    .copyWith(color: MintflowColors.textSecondary(context)),
              ),
            ]),
          ),
        ),
        ),
        const SizedBox(height: 12),

        // Manual option
        Semantics(
          button: true,
          label: "I'll add manually",
          child: InkWell(
          onTap: loading ? null : onManual,
          borderRadius: MintflowRadius.xl_,
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              color: MintflowColors.card(context),
              borderRadius: MintflowRadius.xl_,
              border: Border.all(color: MintflowColors.hairline(context)),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MintflowColors.softFill(context),
                  borderRadius: MintflowRadius.md_,
                ),
                child: Icon(Icons.edit_outlined,
                    color: MintflowColors.textSecondary(context), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("I'll add manually",
                      style: MintflowTextStyles.labelMedium.copyWith(
                        color: MintflowColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                      )),
                  Text('Start exploring the app right away',
                      style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.textSecondary(context),
                      )),
                ],
              )),
            ]),
          ),
        ),
        ),
        const SizedBox(height: 16),

        // Security note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MintflowColors.softFill(context),
            borderRadius: MintflowRadius.md_,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined,
                size: 14, color: MintflowColors.textSecondary(context)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Read-only access. Mintflow cannot move money or '
              'modify your accounts.',
              style: MintflowTextStyles.overline.copyWith(
                  color: MintflowColors.textSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w400),
            )),
          ]),
        ),
        const SizedBox(height: 32),

        _NextButton(
          label: 'Connect bank account',
          onPressed: loading ? null : onConnectBank,
          loading: loading,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: loading ? null : onManual,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text('Maybe later'),
          ),
        ),
      ]),
      ),
    );
  }
}
