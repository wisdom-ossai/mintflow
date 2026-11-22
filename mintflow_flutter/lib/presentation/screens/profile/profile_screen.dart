import 'package:mintflow_flutter/core/router/app_router.dart';
import 'package:mintflow_flutter/core/utils/format.dart';
import 'package:mintflow_flutter/data/datasources/local_cache.dart';
import 'package:mintflow_flutter/data/models/models.dart';
import 'package:mintflow_flutter/presentation/cubits/cubits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../data/datasources/service_locator.dart';
import '../../widgets/amount_edit_sheet.dart';
import '../../widgets/semantic_tap.dart';
import '../../widgets/upgrade_soft_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile — identity, financial summary, deep links (prefs live in Settings)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _sectionsController;

  late Animation<double> _avatarScale;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _sectionsFade;
  late Animation<Offset> _sectionsSlide;

  int _linkedAccountCount = 0;

  // Financial profile
  double? _monthlyBudget;
  double? _monthlySavings;
  String _budgetMethod = 'Needs vs Wants';
  bool _financialLoading = false;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sectionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _avatarScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _sectionsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sectionsController, curve: Curves.easeOut),
    );
    _sectionsSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _sectionsController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _headerController.value = 1;
        _sectionsController.value = 1;
      } else {
        _headerController.forward();
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _sectionsController.forward();
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<UserCubit>().load();
      if (mounted) await _loadFinancialProfile();
      if (mounted) await _loadLinkedAccountCount();
    });
  }

  Future<void> _loadLinkedAccountCount() async {
    try {
      final accounts = await ServiceLocator.instance.api.getAccounts();
      if (!mounted) return;
      setState(() => _linkedAccountCount = accounts.length);
    } catch (_) {}
  }

  Future<void> _loadFinancialProfile() async {
    setState(() => _financialLoading = true);
    try {
      final method =
          MintflowCache.getPref(CacheKeys.budgetMethod) ?? 'Needs vs Wants';
      final savedSavings =
          MintflowCache.getPrefDouble(CacheKeys.monthlySavingsTarget);

      double? budget;
      try {
        final budgets = await ServiceLocator.instance.api.getBudgets();
        for (final b in budgets) {
          if (b['category_id'] == null) {
            budget = double.tryParse(b['amount']?.toString() ?? '');
            break;
          }
        }
      } catch (_) {}

      final userState = context.read<UserCubit>().state;
      final income = userState is UserLoaded ? userState.user.monthlyIncome : null;

      double? savings = savedSavings;
      if (savings == null && income != null && budget != null) {
        savings = (income - budget).clamp(0, double.infinity);
      }

      if (!mounted) return;
      setState(() {
        _budgetMethod = method;
        _monthlyBudget = budget;
        _monthlySavings = savings;
        _financialLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _financialLoading = false);
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _sectionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final gutter = MintBreakpoints.pageGutter(context);
    final expanded = MintBreakpoints.isExpanded(context);

    final financialSection = <Widget>[
      const _SectionLabel(label: 'Financial profile'),
      const SizedBox(height: MintflowSpacing.md),
      _FinancialProfileCard(
        monthlyBudget: _monthlyBudget,
        monthlySavings: _monthlySavings,
        budgetMethod: _budgetMethod,
        loading: _financialLoading,
        onEditBudget: () => context.go(MintflowRoutes.dashboard),
        budgetHint: 'Edit from Home',
        onEditSavings: () => _editSavingsGoal(context),
        onEditMethod: () => _editBudgetMethod(context),
      ),
    ];

    final accountAndDanger = <Widget>[
      _SettingsCard(
        children: [
          BlocBuilder<UserCubit, UserState>(
            builder: (context, userState) {
              final user = userState is UserLoaded ? userState.user : null;
              final tier = user?.effectiveTier.name ?? 'seed';
              final tierLabel =
                  tier[0].toUpperCase() + tier.substring(1);
              return _ActionRow(
                icon: Icons.star_outline,
                iconColor: MintflowColors.green600,
                iconBg: MintflowColors.mintWash(context),
                label: 'Manage plan',
                subtitle: tierLabel,
                onTap: () => openUpgradeFlow(context),
              );
            },
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.account_balance_outlined,
            iconColor: MintflowColors.green500,
            iconBg: MintflowColors.mintWash(context),
            label: 'Linked accounts',
            subtitle: _linkedAccountCount == 0
                ? 'None connected'
                : '$_linkedAccountCount connected',
            onTap: () async {
              await context.push(MintflowRoutes.linkedAccounts);
              if (mounted) await _loadLinkedAccountCount();
            },
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.subscriptions_outlined,
            iconColor: MintflowColors.blue,
            iconBg: MintflowColors.blueWash(context),
            label: 'Subscriptions',
            subtitle: 'Detected from your banks',
            onTap: () =>
                context.push(MintflowRoutes.recurringSubscriptions),
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.receipt_long_outlined,
            iconColor: MintflowColors.blue,
            iconBg: MintflowColors.blueWash(context),
            label: 'Bills',
            subtitle: 'Rent, utilities, due dates',
            onTap: () => context.push(MintflowRoutes.bills),
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.savings_outlined,
            iconColor: MintflowColors.green500,
            iconBg: MintflowColors.mintWash(context),
            label: 'Goals',
            subtitle: 'Save toward a named target',
            onTap: () => context.push(MintflowRoutes.goals),
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.account_balance_outlined,
            iconColor: MintflowColors.gold400,
            iconBg: MintflowColors.goldWash(context),
            label: 'Debt plan',
            subtitle: 'Snowball or avalanche payoff',
            onTap: () => context.push(MintflowRoutes.debtPlan),
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.document_scanner_outlined,
            iconColor: MintflowColors.blue,
            iconBg: MintflowColors.blueWash(context),
            label: 'Scan receipt',
            subtitle: 'OCR expense from a photo',
            onTap: () => context.push(MintflowRoutes.receiptScan),
          ),
          _Divider(),
          _ActionRow(
            icon: Icons.settings_outlined,
            iconColor: MintflowColors.green600,
            iconBg: MintflowColors.mintWash(context),
            label: 'Settings',
            subtitle: 'Appearance, language, notifications',
            onTap: () => context.push(MintflowRoutes.settings),
          ),
        ],
      ),
      const SizedBox(height: MintflowSpacing.xxl),
      _SettingsCard(
        children: [
          _DangerRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            onTap: () => _showSignOutDialog(context),
          ),
          _Divider(),
          _DangerRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete account',
            isDestructive: true,
            onTap: () => _showDeleteDialog(context),
          ),
        ],
      ),
      const SizedBox(height: MintflowSpacing.lg),
      Center(
        child: Text(
          'Mintflow v1.0.0',
          style: MintflowTextStyles.overline.copyWith(
            color: MintflowColors.textTertiary(context),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: MintflowColors.green900,
      body: Column(
        children: [
          // ── Dark header ──────────────────────────────────────────────────
          BlocBuilder<UserCubit, UserState>(
            builder: (context, userState) {
              final user = userState is UserLoaded ? userState.user : null;
              return _ProfileHeader(
                top: top,
                avatarScale: _avatarScale,
                fade: _headerFade,
                slide: _headerSlide,
                user: user,
                onOpenSettings: () =>
                    context.push(MintflowRoutes.settings),
                onManagePlan: () => openUpgradeFlow(context),
              );
            },
          ),

          // ── Scrollable cream body ────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: MintflowColors.page(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FadeTransition(
                opacity: _sectionsFade,
                child: SlideTransition(
                  position: _sectionsSlide,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 32),
                      child: MintAdaptiveWidth(
                        maxWidth: MintBreakpoints.contentMax,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (expanded) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: financialSection,
                                  ),
                                ),
                                const SizedBox(width: MintflowSpacing.xl),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _SectionLabel(label: 'Account'),
                                      const SizedBox(
                                          height: MintflowSpacing.md),
                                      ...accountAndDanger,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            ...financialSection,
                            const SizedBox(height: MintflowSpacing.xxl),
                            const _SectionLabel(label: 'Account'),
                            const SizedBox(height: MintflowSpacing.md),
                            ...accountAndDanger,
                          ],
                        ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pickers & dialogs ──────────────────────────────────────────────────────

  void _editBudgetMethod(BuildContext context) {
    const methods = [
      'Needs vs Wants',
      '50/30/20',
      'Zero-based',
      'Pay yourself first',
    ];
    _showOptionSheet(
      context,
      title: 'Budget method',
      options: methods,
      selected: _budgetMethod,
      onSelect: (v) async {
        setState(() => _budgetMethod = v);
        await MintflowCache.setPref(CacheKeys.budgetMethod, v);
      },
    );
  }

  Future<void> _editSavingsGoal(BuildContext context) async {
    final amount = await AmountEditSheet.show(
      context,
      title: 'Monthly savings goal',
      subtitle: 'How much do you want to save each month?',
      initial: _monthlySavings,
      confirmLabel: 'Save goal',
    );
    if (amount == null || !mounted) return;

    setState(() => _financialLoading = true);
    try {
      await MintflowCache.setPrefDouble(
          CacheKeys.monthlySavingsTarget, amount);

      final userState = context.read<UserCubit>().state;
      final income =
          userState is UserLoaded ? userState.user.monthlyIncome : null;

      double? budget = _monthlyBudget;
      if (income != null && income > 0) {
        budget = (income - amount).clamp(0, double.infinity).toDouble();
        await ServiceLocator.instance.api.createBudget({
          'amount': budget,
          'period': 'monthly',
          'category_id': null,
          'rollover': false,
        });
        await MintflowCache.invalidateDashboard();
        if (mounted) context.read<DashboardCubit>().refresh();
      }

      if (!mounted) return;
      setState(() {
        _monthlySavings = amount;
        _monthlyBudget = budget;
        _financialLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Savings goal set to ${MintflowFormat.currency(amount)} / mo.'),
          backgroundColor: MintflowColors.green900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
          margin: const EdgeInsets.all(MintflowSpacing.lg),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _financialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: MintflowColors.red,
        ),
      );
    }
  }

  void _showOptionSheet(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: MintBreakpoints.formMax),
      builder: (_) => _OptionSheet(
        title: title,
        options: options,
        selected: selected,
        onSelect: (v) {
          onSelect(v);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await ServiceLocator.instance.api.logout();
      AuthGate.onboardingComplete.value = null;
      if (mounted) context.go(MintflowRoutes.login);
    } catch (e) {
      // Still clear local session if revoke fails
      await ServiceLocator.instance.tokens.clear();
      AuthGate.onboardingComplete.value = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyAuthError(e)),
            backgroundColor: MintflowColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
            margin: const EdgeInsets.all(16),
          ),
        );
        context.go(MintflowRoutes.login);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final cubit = context.read<UserCubit>();
    final ok = await cubit.deleteAccount();
    if (!mounted) return;
    if (!ok) {
      final err = cubit.state;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err is UserError
              ? err.message
              : 'Couldn’t delete your account. Check your connection and try again.'),
          backgroundColor: MintflowColors.red,
        ),
      );
      return;
    }
    try {
      await ServiceLocator.instance.api.logout();
    } catch (_) {
      await ServiceLocator.instance.tokens.clear();
    }
    AuthGate.onboardingComplete.value = null;
    if (mounted) context.go(MintflowRoutes.login);
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You\'ll need to log in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently erase all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MintflowColors.red,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAccount();
            },
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final double top;
  final Animation<double> avatarScale;
  final Animation<double> fade;
  final Animation<Offset> slide;
  final UserModel? user;
  final VoidCallback onOpenSettings;
  final VoidCallback onManagePlan;

  const _ProfileHeader({
    required this.top,
    required this.avatarScale,
    required this.fade,
    required this.slide,
    required this.onOpenSettings,
    required this.onManagePlan,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '…';
    final email = user?.email ?? '';
    final initials = user?.initials ?? '?';
    final memberSince = user != null
        ? 'Member since ${MintflowFormat.monthShort(user!.createdAt)}'
        : 'Loading profile…';
    final incomeLabel = user?.monthlyIncome != null
        ? MintflowFormat.currencyCompact(user!.monthlyIncome!)
        : '—';
    final tierLabel = user != null
        ? user!.effectiveTier.name[0].toUpperCase() +
            user!.effectiveTier.name.substring(1)
        : '—';

    return Container(
      color: MintflowColors.green900,
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 28),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MintflowColors.green400.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MintflowColors.gold400.withValues(alpha: 0.05),
              ),
            ),
          ),
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Settings',
                      onPressed: onOpenSettings,
                      icon: Icon(
                        Icons.settings_outlined,
                        color: MintflowColors.cream,
                      ),
                    ),
                  ),
                  ScaleTransition(
                    scale: avatarScale,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                MintflowColors.green400,
                                MintflowColors.green600,
                              ],
                            ),
                            border: Border.all(
                              color: MintflowColors.green600,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: MintflowTextStyles.displaySmall.copyWith(
                                color: MintflowColors.onMint(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Edit profile photo',
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: MintflowColors.gold400,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MintflowColors.green900,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: MintflowColors.onMint(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: MintflowTextStyles.displaySmall.copyWith(
                      color: MintflowColors.cream,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: MintflowTextStyles.bodySmall.copyWith(
                      color: MintflowColors.onBrandMuted(context, 0.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HeaderBadge(
                    icon: Icons.verified_rounded,
                    label: memberSince,
                    color: MintflowColors.gold400,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderStat(
                          value: incomeLabel,
                          label: 'Monthly income',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: MintflowColors.brandOverlay(context, 0.1),
                      ),
                      Expanded(
                        child: _HeaderStat(
                          value: tierLabel,
                          label: 'Plan',
                          onTap: onManagePlan,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: MintflowColors.brandOverlay(context, 0.1),
                      ),
                      Expanded(
                        child: _HeaderStat(
                          value: user?.currency ?? 'USD',
                          label: 'Currency',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: MintflowRadius.pill_,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: MintflowTextStyles.overline.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _HeaderStat({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      children: [
        Text(
          value,
          style: MintflowTextStyles.labelLarge.copyWith(
            color: MintflowColors.cream,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: MintflowTextStyles.overline.copyWith(
            color: MintflowColors.onBrandMuted(context, 0.45),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
    if (onTap == null) return column;
    return SemanticTap(
      label: '$label, $value',
      onTap: onTap,
      child: column,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Financial Profile Card
// ─────────────────────────────────────────────────────────────────────────────

class _FinancialProfileCard extends StatelessWidget {
  final double? monthlyBudget;
  final double? monthlySavings;
  final String budgetMethod;
  final bool loading;
  final VoidCallback onEditBudget;
  final String budgetHint;
  final VoidCallback onEditSavings;
  final VoidCallback onEditMethod;

  const _FinancialProfileCard({
    required this.monthlyBudget,
    required this.monthlySavings,
    required this.budgetMethod,
    required this.loading,
    required this.onEditBudget,
    required this.budgetHint,
    required this.onEditSavings,
    required this.onEditMethod,
  });

  @override
  Widget build(BuildContext context) {
    final budgetValue = monthlyBudget != null
        ? MintflowFormat.currency(monthlyBudget!)
        : 'Not set';
    final savingsValue = monthlySavings != null
        ? '${MintflowFormat.currency(monthlySavings!)} / mo.'
        : 'Not set';

    return _SettingsCard(
      children: [
        _InfoRow(
          icon: Icons.wallet_outlined,
          iconColor: MintflowColors.green500,
          iconBg: MintflowColors.mintWash(context),
          label: 'Monthly budget',
          value: loading ? '…' : budgetValue,
          subtitle: budgetHint,
          onTap: onEditBudget,
        ),
        _Divider(),
        _InfoRow(
          icon: Icons.savings_outlined,
          iconColor: MintflowColors.green600,
          iconBg: MintflowColors.mintWash(context),
          label: 'Savings goal',
          value: loading ? '…' : savingsValue,
          onTap: onEditSavings,
        ),
        _Divider(),
        _InfoRow(
          icon: Icons.category_outlined,
          iconColor: MintflowColors.blue,
          iconBg: MintflowColors.blueWash(context),
          label: 'Budget method',
          value: budgetMethod,
          onTap: onEditMethod,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable setting row types
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        borderRadius: MintflowRadius.lg_,
        border: Border.all(color: MintflowColors.hairline(context)),
      ),
      child: Column(children: children),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: MintflowTextStyles.overline.copyWith(
        color: MintflowColors.textSecondary(context),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: MintflowColors.hairline(context)),
    );
  }
}

class _RowIconBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _RowIconBox({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = subtitle == null
        ? 'Edit $label, $value'
        : '$label, $value. $subtitle';
    return SemanticTap(
      label: semantic,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MintflowSpacing.lg,
          vertical: MintflowSpacing.md,
        ),
        child: Row(
          children: [
            _RowIconBox(icon: icon, iconColor: iconColor, iconBg: iconBg),
            const SizedBox(width: MintflowSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintflowTextStyles.labelMedium.copyWith(
                      color: MintflowColors.textPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.green500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: MintflowSpacing.xs),
            Icon(
              subtitle != null
                  ? Icons.chevron_right_rounded
                  : Icons.edit_outlined,
              color: MintflowColors.textTertiary(context),
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = subtitle == null ? label : '$label, $subtitle';
    return SemanticTap(
      label: semantic,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _RowIconBox(icon: icon, iconColor: iconColor, iconBg: iconBg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintflowTextStyles.labelMedium.copyWith(
                      color: MintflowColors.textPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.textTertiary(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DangerRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? MintflowColors.red : MintflowColors.textSecondary(context);
    return SemanticTap(
      label: label,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDestructive
                    ? MintflowColors.redWash(context)
                    : MintflowColors.softFill(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: MintflowTextStyles.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OptionSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintflowColors.page(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MintflowColors.hairline(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: MintflowTextStyles.displaySmall.copyWith(
              color: MintflowColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: MintflowColors.card(context),
              borderRadius: MintflowRadius.lg_,
              border: Border.all(color: MintflowColors.hairline(context)),
            ),
            child: Column(
              children: options.map((opt) {
                final isSelected = opt == selected;
                final isLast = opt == options.last;
                return Column(
                  children: [
                    SemanticTap(
                      label: opt,
                      selected: isSelected,
                      onTap: () => onSelect(opt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                opt,
                                style: MintflowTextStyles.labelMedium.copyWith(
                                  color: isSelected
                                      ? MintflowColors.green500
                                      : MintflowColors.textPrimary(context),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_rounded,
                                color: MintflowColors.green500,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(height: 1, color: MintflowColors.hairline(context)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
