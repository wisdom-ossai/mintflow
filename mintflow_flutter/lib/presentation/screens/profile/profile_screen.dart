import 'package:mintflow_flutter/core/router/app_router.dart';
import 'package:mintflow_flutter/core/utils/format.dart';
import 'package:mintflow_flutter/data/datasources/local_cache.dart';
import 'package:mintflow_flutter/data/models/models.dart';
import 'package:mintflow_flutter/presentation/cubits/cubits.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/appearance_control.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../data/datasources/service_locator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile + Settings Screen
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

  // Settings state
  bool _notificationsEnabled = true;
  bool _weeklyReport = true;
  bool _budgetAlerts = true;
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'English';
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

    _avatarScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
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

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _sectionsController.forward();
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
        if (userState is UserLoaded) {
          _selectedCurrency = userState.user.currency;
        }
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
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Financial profile
                          _SectionLabel(label: 'Financial Profile'),
                          const SizedBox(height: 10),
                          _FinancialProfileCard(
                            monthlyBudget: _monthlyBudget,
                            monthlySavings: _monthlySavings,
                            budgetMethod: _budgetMethod,
                            loading: _financialLoading,
                            onEditBudget: () => _editMonthlyBudget(context),
                            onEditSavings: () => _editSavingsGoal(context),
                            onEditMethod: () => _editBudgetMethod(context),
                          ),

                          const SizedBox(height: 24),

                          // Notifications settings (local for now)
                          // TODO: sync toggles to PUT /notifications/preferences
                          _SectionLabel(label: 'Notifications'),
                          const SizedBox(height: 10),
                          _SettingsCard(
                            children: [
                              _ToggleRow(
                                icon: Icons.notifications_outlined,
                                iconColor: MintflowColors.green500,
                                iconBg: MintflowColors.green50,
                                label: 'Push notifications',
                                subtitle: 'Alerts, tips & reminders',
                                value: _notificationsEnabled,
                                onChanged: (v) => setState(
                                  () => _notificationsEnabled = v,
                                ),
                              ),
                              _Divider(),
                              _ToggleRow(
                                icon: Icons.bar_chart_outlined,
                                iconColor: MintflowColors.blue,
                                iconBg: MintflowColors.blueSoft,
                                label: 'Weekly report',
                                subtitle: 'Summary every Sunday',
                                value: _weeklyReport,
                                onChanged: (v) =>
                                    setState(() => _weeklyReport = v),
                              ),
                              _Divider(),
                              _ToggleRow(
                                icon: Icons.warning_amber_rounded,
                                iconColor: MintflowColors.gold500,
                                iconBg: MintflowColors.gold50,
                                label: 'Budget alerts',
                                subtitle: 'Notify when near limit',
                                value: _budgetAlerts,
                                onChanged: (v) =>
                                    setState(() => _budgetAlerts = v),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Preferences
                          _SectionLabel(label: 'Preferences'),
                          const SizedBox(height: 10),
                          _SettingsCard(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Appearance',
                                      style: MintflowTextStyles.labelMedium
                                          .copyWith(
                                        color: MintflowColors.textPrimary(
                                            context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Light, dark, or match this device',
                                      style: MintflowTextStyles.overline
                                          .copyWith(
                                        color: MintflowColors.textSecondary(
                                            context),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const AppearanceControl(),
                                  ],
                                ),
                              ),
                              _Divider(),
                              _SelectRow(
                                icon: Icons.language_outlined,
                                iconColor: MintflowColors.blue,
                                iconBg: MintflowColors.blueSoft,
                                label: 'Language',
                                value: _selectedLanguage,
                                onTap: () => _showLanguagePicker(context),
                              ),
                              _Divider(),
                              _SelectRow(
                                icon: Icons.attach_money_rounded,
                                iconColor: MintflowColors.gold500,
                                iconBg: MintflowColors.gold50,
                                label: 'Currency',
                                value: _selectedCurrency,
                                onTap: () => _showCurrencyPicker(context),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Account
                          _SectionLabel(label: 'Account'),
                          const SizedBox(height: 10),
                          _SettingsCard(
                            children: [
                              _ActionRow(
                                icon: Icons.account_balance_outlined,
                                iconColor: MintflowColors.green500,
                                iconBg: MintflowColors.green50,
                                label: 'Linked accounts',
                                subtitle: _linkedAccountCount == 0
                                    ? 'None connected'
                                    : '$_linkedAccountCount connected',
                                onTap: () async {
                                  await context
                                      .push(MintflowRoutes.linkedAccounts);
                                  if (mounted) await _loadLinkedAccountCount();
                                },
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.subscriptions_outlined,
                                iconColor: MintflowColors.purple,
                                iconBg: MintflowColors.purpleSoft,
                                label: 'Subscriptions',
                                subtitle: 'Detected from your banks',
                                onTap: () => context.push(
                                    MintflowRoutes.recurringSubscriptions),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.receipt_long_outlined,
                                iconColor: MintflowColors.blue,
                                iconBg: MintflowColors.blueSoft,
                                label: 'Bills',
                                subtitle: 'Rent, utilities, due dates',
                                onTap: () =>
                                    context.push(MintflowRoutes.bills),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.download_outlined,
                                iconColor: MintflowColors.blue,
                                iconBg: MintflowColors.blueSoft,
                                label: 'Export data',
                                subtitle: 'CSV (Pro)',
                                onTap: () =>
                                    context.push(MintflowRoutes.exportData),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.security_outlined,
                                iconColor: MintflowColors.purple,
                                iconBg: MintflowColors.purpleSoft,
                                label: 'Privacy & security',
                                onTap: () => context
                                    .push(MintflowRoutes.privacySecurity),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Support
                          _SectionLabel(label: 'Support'),
                          const SizedBox(height: 10),
                          _SettingsCard(
                            children: [
                              _ActionRow(
                                icon: Icons.help_outline_rounded,
                                iconColor: MintflowColors.green500,
                                iconBg: MintflowColors.green50,
                                label: 'Help center',
                                onTap: () => _showStub(context, 'Help center'),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                iconColor: MintflowColors.blue,
                                iconBg: MintflowColors.blueSoft,
                                label: 'Send feedback',
                                onTap: () =>
                                    _showStub(context, 'Send feedback'),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.description_outlined,
                                iconColor: MintflowColors.ink60,
                                iconBg: MintflowColors.creamDark,
                                label: 'Terms & Privacy policy',
                                onTap: () => _showStub(
                                    context, 'Terms & Privacy policy'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Danger zone
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

                          const SizedBox(height: 16),

                          // App version
                          Center(
                            child: Text(
                              'Mintflow v1.0.0',
                              style: MintflowTextStyles.overline.copyWith(
                                color: MintflowColors.textTertiary(context),
                              ),
                            ),
                          ),
                        ],
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

  void _showLanguagePicker(BuildContext context) {
    final languages = ['English', 'French', 'Spanish', 'German', 'Arabic'];
    _showOptionSheet(
      context,
      title: 'Language',
      options: languages,
      selected: _selectedLanguage,
      onSelect: (v) => setState(() => _selectedLanguage = v),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    final currencies = ['USD', 'EUR', 'GBP', 'NGN', 'CAD', 'AUD'];
    _showOptionSheet(
      context,
      title: 'Currency',
      options: currencies,
      selected: _selectedCurrency,
      onSelect: (v) async {
        setState(() => _selectedCurrency = v);
        await context.read<UserCubit>().updateProfile({'currency': v});
      },
    );
  }

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

  Future<void> _editMonthlyBudget(BuildContext context) async {
    final amount = await _showAmountSheet(
      context,
      title: 'Monthly budget',
      subtitle: 'How much do you plan to spend each month?',
      initial: _monthlyBudget,
      confirmLabel: 'Save budget',
    );
    if (amount == null || !mounted) return;

    setState(() => _financialLoading = true);
    try {
      await ServiceLocator.instance.api.createBudget({
        'amount': amount,
        'period': 'monthly',
        'category_id': null,
        'rollover': false,
      });
      await MintflowCache.invalidateDashboard();

      final userState = context.read<UserCubit>().state;
      final income =
          userState is UserLoaded ? userState.user.monthlyIncome : null;
      final savings = income != null
          ? (income - amount).clamp(0, double.infinity).toDouble()
          : _monthlySavings;

      if (savings != null) {
        await MintflowCache.setPrefDouble(
            CacheKeys.monthlySavingsTarget, savings);
      }

      if (!mounted) return;
      setState(() {
        _monthlyBudget = amount;
        _monthlySavings = savings;
        _financialLoading = false;
      });
      context.read<DashboardCubit>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Monthly budget set to ${MintflowFormat.currency(amount)}'),
          backgroundColor: MintflowColors.green900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
          margin: const EdgeInsets.all(16),
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

  Future<void> _editSavingsGoal(BuildContext context) async {
    final amount = await _showAmountSheet(
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
      // If income is known, keep spend budget in sync: budget = income − savings
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
          margin: const EdgeInsets.all(16),
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

  Future<double?> _showAmountSheet(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double? initial,
    required String confirmLabel,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmountEditSheet(
        title: title,
        subtitle: subtitle,
        initial: initial,
        confirmLabel: confirmLabel,
      ),
    );
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

  void _showStub(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon'),
        backgroundColor: MintflowColors.green900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
        margin: const EdgeInsets.all(16),
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
              : 'Could not delete account'),
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
      builder: (_) => _MintflowDialog(
        title: 'Sign out?',
        message: 'You\'ll need to log in again to access your account.',
        confirmLabel: 'Sign out',
        isDestructive: false,
        onConfirm: () => _logout(),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _MintflowDialog(
        title: 'Delete account?',
        message:
            'This will permanently erase all your data. This action cannot be undone.',
        confirmLabel: 'Delete account',
        isDestructive: true,
        onConfirm: () => _deleteAccount(),
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

  const _ProfileHeader({
    required this.top,
    required this.avatarScale,
    required this.fade,
    required this.slide,
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
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 28),
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
                color: MintflowColors.green400.withOpacity(0.07),
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
                color: MintflowColors.gold400.withOpacity(0.05),
              ),
            ),
          ),
          FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Column(
                children: [
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
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: MintflowColors.gold400,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MintflowColors.green900,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 12,
                            color: Colors.white,
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
                      color: MintflowColors.cream.withOpacity(0.5),
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
                        color: Colors.white.withOpacity(0.1),
                      ),
                      Expanded(
                        child: _HeaderStat(
                          value: tierLabel,
                          label: 'Plan',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withOpacity(0.1),
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
        color: color.withOpacity(0.12),
        borderRadius: MintflowRadius.pill_,
        border: Border.all(color: color.withOpacity(0.25)),
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

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
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
            color: MintflowColors.cream.withOpacity(0.45),
          ),
          textAlign: TextAlign.center,
        ),
      ],
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
  final VoidCallback onEditSavings;
  final VoidCallback onEditMethod;

  const _FinancialProfileCard({
    required this.monthlyBudget,
    required this.monthlySavings,
    required this.budgetMethod,
    required this.loading,
    required this.onEditBudget,
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
          iconBg: MintflowColors.green50,
          label: 'Monthly budget',
          value: loading ? '…' : budgetValue,
          onTap: onEditBudget,
        ),
        _Divider(),
        _InfoRow(
          icon: Icons.savings_outlined,
          iconColor: MintflowColors.gold500,
          iconBg: MintflowColors.gold50,
          label: 'Savings goal',
          value: loading ? '…' : savingsValue,
          onTap: onEditSavings,
        ),
        _Divider(),
        _InfoRow(
          icon: Icons.category_outlined,
          iconColor: MintflowColors.blue,
          iconBg: MintflowColors.blueSoft,
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
        border: Border.all(color: MintflowColors.stroke(context)),
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
      label.toUpperCase(),
      style: MintflowTextStyles.overline.copyWith(
        color: MintflowColors.textSecondary(context),
        letterSpacing: 0.08,
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

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          _MintflowSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _RowIconBox(icon: icon, iconColor: iconColor, iconBg: iconBg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: MintflowTextStyles.labelMedium.copyWith(
                  color: MintflowColors.textPrimary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.textSecondary(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.textTertiary(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _RowIconBox(icon: icon, iconColor: iconColor, iconBg: iconBg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: MintflowTextStyles.labelMedium.copyWith(
                  color: MintflowColors.textPrimary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.green500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                color: MintflowColors.textTertiary(context), size: 15),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
// Custom Mintflow Switch
// ─────────────────────────────────────────────────────────────────────────────

class _MintflowSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MintflowSwitch({required this.value, required this.onChanged});

  @override
  State<_MintflowSwitch> createState() => _MintflowSwitchState();
}

class _MintflowSwitchState extends State<_MintflowSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _thumbAnim;
  late Animation<Color?> _trackAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.value ? 1.0 : 0.0,
    );
    _thumbAnim = Tween<double>(begin: 2, end: 22).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _trackAnim = ColorTween(
      begin: MintflowColors.ink10,
      end: MintflowColors.green400,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_MintflowSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onChanged(!widget.value);
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Container(
          width: 46,
          height: 26,
          decoration: BoxDecoration(
            color: _trackAnim.value,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Stack(
            children: [
              Positioned(
                left: _thumbAnim.value,
                top: 2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              border: Border.all(color: MintflowColors.stroke(context)),
            ),
            child: Column(
              children: options.map((opt) {
                final isSelected = opt == selected;
                final isLast = opt == options.last;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () => onSelect(opt),
                      behavior: HitTestBehavior.opaque,
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
// Mintflow Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _MintflowDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const _MintflowDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MintflowColors.card(context),
      shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: MintflowTextStyles.displaySmall.copyWith(
                color: MintflowColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: MintflowTextStyles.bodyMedium.copyWith(
                color: MintflowColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive
                          ? MintflowColors.red
                          : MintflowColors.green400,
                    ),
                    onPressed: onConfirm,
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amount edit bottom sheet (budget / savings)
// ─────────────────────────────────────────────────────────────────────────────

class _AmountEditSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final double? initial;
  final String confirmLabel;

  const _AmountEditSheet({
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.confirmLabel,
  });

  @override
  State<_AmountEditSheet> createState() => _AmountEditSheetState();
}

class _AmountEditSheetState extends State<_AmountEditSheet> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initial != null
          ? widget.initial!.toStringAsFixed(
              widget.initial! == widget.initial!.roundToDouble() ? 0 : 2)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop(context, amount);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintflowColors.hairline(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: MintflowTextStyles.displaySmall
                  .copyWith(color: MintflowColors.textPrimary(context)),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.textSecondary(context)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: MintflowTextStyles.amountSmall
                  .copyWith(color: MintflowColors.textPrimary(context)),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
