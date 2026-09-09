import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/service_locator.dart';
import '../../../data/models/models.dart';
import '../../cubits/cubits.dart';

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

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(
        _step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
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
            content: Text('Could not save profile: $e'),
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
        context.go('${MintflowRoutes.paywall}?feature=bank_sync');
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
                content: Text('Bank linked but sync failed — try again later.'),
                backgroundColor: MintflowColors.gold500,
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
          final msg = exit.error?.displayMessage ??
              exit.error?.message ??
              'Bank connection cancelled';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: MintflowColors.ink60),
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
            content: Text('Could not open bank link: $e'),
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
      backgroundColor: MintflowColors.cream,
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
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
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
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? MintflowColors.green400
                          : done
                              ? MintflowColors.green400.withOpacity(0.5)
                              : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  AuthGate.setOnboardingComplete(true);
                  context.go(MintflowRoutes.dashboard);
                },
                child: Text('Skip',
                    style: MintflowTextStyles.labelSmall
                        .copyWith(color: Colors.white.withOpacity(0.5))),
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
                  .copyWith(color: MintflowColors.ink60)),
        ],
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style:
                MintflowTextStyles.overline.copyWith(color: MintflowColors.ink60)),
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
                      color: Colors.white, strokeWidth: 2))
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
      padding: const EdgeInsets.all(24),
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
            color: MintflowColors.green50,
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

        _FieldLabel('Your name'),
        TextFormField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Alex Johnson'),
        ),
        const SizedBox(height: 12),

        _FieldLabel('Email'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: MintflowColors.creamDark,
            borderRadius: MintflowRadius.lg_,
            border: Border.all(color: MintflowColors.ink10, width: 1.5),
          ),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 16, color: MintflowColors.ink60),
            const SizedBox(width: 8),
            Text(
              email.isNotEmpty ? email : 'Loading…',
              style: MintflowTextStyles.bodyMedium
                  .copyWith(color: MintflowColors.ink60),
            ),
          ]),
        ),
        const SizedBox(height: 36),
        _NextButton(label: 'Continue', onPressed: onNext),
      ]),
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
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const _StepHeader(
          title: 'Set your\nspending target',
          subtitle: "We'll track this every month.",
        ),
        const SizedBox(height: 28),

        _FieldLabel('Monthly income (optional)'),
        TextFormField(
          controller: incomeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => onIncomeChanged(),
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: '5,000',
          ),
        ),
        const SizedBox(height: 20),

        _FieldLabel('Monthly spending target'),
        TextFormField(
          controller: targetCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: '3,500',
          ),
        ),
        const SizedBox(height: 12),

        // AI suggestion chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
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
          child: const Text("Skip for now"),
        )),
      ]),
    );
  }
}

// ── Step 3 — Connect bank ─────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const _StepHeader(
          title: 'Connect your\naccounts',
          subtitle: 'Bank, credit cards, or go manual.',
        ),
        const SizedBox(height: 28),

        // Plaid option — recommended
        GestureDetector(
          onTap: onConnectBank,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: MintflowRadius.xl_,
              border: Border.all(color: MintflowColors.green400, width: 1.5),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: MintflowColors.green400,
                    borderRadius: MintflowRadius.md_,
                  ),
                  child: const Icon(Icons.account_balance_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connect bank or card',
                        style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    Text('Secure sync via Plaid',
                        style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 11,
                            color: Color(0x990F1F14))),
                  ],
                )),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MintflowColors.green50,
                    borderRadius: MintflowRadius.pill_,
                  ),
                  child: Text('Recommended',
                      style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.green600,
                          fontWeight: FontWeight.w500)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                'Your credentials never touch Mintflow. '
                '10,000+ US banks supported.',
                style: MintflowTextStyles.bodySmall
                    .copyWith(color: MintflowColors.ink60),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Manual option
        GestureDetector(
          onTap: onManual,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: MintflowRadius.xl_,
              border: Border.all(color: MintflowColors.ink10),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: MintflowColors.creamDark,
                  borderRadius: MintflowRadius.md_,
                ),
                child: Icon(Icons.edit_outlined,
                    color: MintflowColors.ink60, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("I'll add manually",
                      style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Text('Log cash, local banks, anything',
                      style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 11,
                          color: Color(0x990F1F14))),
                ],
              )),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Security note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: MintflowColors.creamDark,
            borderRadius: MintflowRadius.md_,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, size: 14, color: MintflowColors.ink60),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Read-only access. Mintflow cannot move money or '
              'modify your accounts.',
              style: MintflowTextStyles.overline.copyWith(
                  color: MintflowColors.ink60,
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
          child: const Text("I'll start manually"),
        )),
      ]),
    );
  }
}
