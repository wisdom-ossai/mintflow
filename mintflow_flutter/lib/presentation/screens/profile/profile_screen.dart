import 'package:mintflow_flutter/core/router/app_router.dart';
import 'package:mintflow_flutter/core/utils/format.dart';
import 'package:mintflow_flutter/data/models/models.dart';
import 'package:mintflow_flutter/presentation/cubits/cubits.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _darkModeEnabled = false;
  bool _biometricEnabled = true;
  bool _weeklyReport = true;
  bool _budgetAlerts = true;
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'English';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserCubit>().load();
    });
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
              decoration: const BoxDecoration(
                color: MintflowColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          _FinancialProfileCard(),

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
                              _ToggleRow(
                                icon: Icons.dark_mode_outlined,
                                iconColor: MintflowColors.purple,
                                iconBg: MintflowColors.purpleSoft,
                                label: 'Dark mode',
                                subtitle: 'Switch to dark theme',
                                value: _darkModeEnabled,
                                onChanged: (v) =>
                                    setState(() => _darkModeEnabled = v),
                              ),
                              _Divider(),
                              _ToggleRow(
                                icon: Icons.fingerprint_rounded,
                                iconColor: MintflowColors.green500,
                                iconBg: MintflowColors.green50,
                                label: 'Biometric lock',
                                subtitle: 'Face ID / Fingerprint',
                                value: _biometricEnabled,
                                onChanged: (v) =>
                                    setState(() => _biometricEnabled = v),
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
                                subtitle: '2 connected',
                                onTap: () =>
                                    _showStub(context, 'Linked accounts'),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.download_outlined,
                                iconColor: MintflowColors.blue,
                                iconBg: MintflowColors.blueSoft,
                                label: 'Export data',
                                subtitle: 'CSV or PDF',
                                onTap: () => _showStub(context, 'Export data'),
                              ),
                              _Divider(),
                              _ActionRow(
                                icon: Icons.security_outlined,
                                iconColor: MintflowColors.purple,
                                iconBg: MintflowColors.purpleSoft,
                                label: 'Privacy & security',
                                onTap: () =>
                                    _showStub(context, 'Privacy & security'),
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
                                color: MintflowColors.ink30,
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
      onSelect: (v) => setState(() => _selectedCurrency = v),
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
  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        _InfoRow(
          icon: Icons.wallet_outlined,
          iconColor: MintflowColors.green500,
          iconBg: MintflowColors.green50,
          label: 'Monthly budget',
          value: '\$3,500',
          onTap: () {},
        ),
        _Divider(),
        _InfoRow(
          icon: Icons.savings_outlined,
          iconColor: MintflowColors.gold500,
          iconBg: MintflowColors.gold50,
          label: 'Savings goal',
          value: '\$500 / mo.',
          onTap: () {},
        ),
        _Divider(),
        _InfoRow(
          icon: Icons.category_outlined,
          iconColor: MintflowColors.blue,
          iconBg: MintflowColors.blueSoft,
          label: 'Budget method',
          value: 'Needs vs Wants',
          onTap: () {},
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
        color: Colors.white,
        borderRadius: MintflowRadius.lg_,
        border: Border.all(color: MintflowColors.creamDark),
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
        color: MintflowColors.ink60,
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
      child: Divider(height: 1, color: MintflowColors.ink10),
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
                    color: MintflowColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: MintflowTextStyles.overline.copyWith(
                      color: MintflowColors.ink60,
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
                  color: MintflowColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.ink60,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.ink30, size: 18),
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
                  color: MintflowColors.ink,
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
            Icon(Icons.edit_outlined, color: MintflowColors.ink30, size: 15),
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
                      color: MintflowColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.ink60,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.ink30, size: 18),
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
    final color = isDestructive ? MintflowColors.red : MintflowColors.ink60;
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
                    ? MintflowColors.redSoft
                    : MintflowColors.creamDark,
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
        color: MintflowColors.cream,
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
              color: MintflowColors.ink10,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: MintflowTextStyles.displaySmall.copyWith(
              color: MintflowColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: MintflowRadius.lg_,
              border: Border.all(color: MintflowColors.creamDark),
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
                                      : MintflowColors.ink,
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
                    if (!isLast) Divider(height: 1, color: MintflowColors.ink10),
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
      backgroundColor: Colors.white,
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
                color: MintflowColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: MintflowTextStyles.bodyMedium.copyWith(
                color: MintflowColors.ink60,
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
