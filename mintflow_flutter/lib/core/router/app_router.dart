import 'dart:math' as math;
import 'package:mintflow_flutter/presentation/screens/auth/check_email_screen.dart';
import 'package:mintflow_flutter/presentation/screens/auth/forgot_password_screen.dart';
import 'package:mintflow_flutter/presentation/screens/auth/reset_password_screen.dart';
import 'package:mintflow_flutter/presentation/screens/profile/profile_screen.dart';
import 'package:mintflow_flutter/presentation/screens/profile/linked_accounts_screen.dart';
import 'package:mintflow_flutter/presentation/screens/profile/export_data_screen.dart';
import 'package:mintflow_flutter/presentation/screens/profile/privacy_security_screen.dart';
import 'package:mintflow_flutter/presentation/screens/subscriptions/recurring_subscriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:mintflow_flutter/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_gate.dart';
import '../../presentation/screens/auth/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/signup_screen.dart';
import '../../presentation/screens/auth/onboarding_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/notifications/in_app_notifications_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/transactions/transaction_list_screen.dart';
import '../../presentation/screens/transactions/add_transaction_screen.dart';
import '../../presentation/screens/goals/goals_screen.dart';
import '../../presentation/screens/goals/add_goal_screen.dart';
import '../../presentation/screens/bills/bills_screen.dart';
import '../../presentation/screens/bills/add_bill_screen.dart';
import '../../presentation/screens/insights/insights_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/subscription/paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow Router — wired to real screen implementations
// ─────────────────────────────────────────────────────────────────────────────

class MintflowRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const onboarding = '/onboarding';
  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const addTx = '/transactions/add';
  static const goals = '/goals';
  static const addGoal = '/goals/add';
  static const bills = '/bills';
  static const addBill = '/bills/add';
  static const insights = '/insights';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const notificationSettings = '/notifications/settings';
  static const paywall = '/paywall';
  static const profile = '/profile';
  static const linkedAccounts = '/profile/linked-accounts';
  static const exportData = '/profile/export-data';
  static const privacySecurity = '/profile/privacy-security';
  static const recurringSubscriptions = '/subscriptions/tracked';
  static const forgotPassword = '/forgot-password';
  static const checkEmail = '/check-email';
  static const resetPassword = '/reset-password';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Combines token session + 401 + onboarding flag for go_router refresh.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh() {
    AuthGate.isAuthenticated.addListener(notifyListeners);
    AuthGate.unauthorizedTick.addListener(notifyListeners);
    AuthGate.onboardingComplete.addListener(notifyListeners);
  }
}

GoRouter buildRouter() {
  final refresh = _RouterRefresh();
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: MintflowRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final isLoggedIn = AuthGate.isAuthenticated.value;
      final loc = state.matchedLocation;

      // Splash owns first navigation after animation
      if (loc == MintflowRoutes.splash) return null;

      final isAuthRoute = loc.startsWith('/login') ||
          loc.startsWith('/signup') ||
          loc.startsWith('/onboarding') ||
          loc.startsWith('/forgot-password') ||
          loc.startsWith('/check-email') ||
          loc.startsWith('/reset-password');

      if (!isLoggedIn && !isAuthRoute) return MintflowRoutes.login;

      // Incomplete onboarding → force wizard (splash sets AuthGate flag)
      final onboarded = AuthGate.onboardingComplete.value;
      if (isLoggedIn && onboarded == false && loc != MintflowRoutes.onboarding) {
        return MintflowRoutes.onboarding;
      }

      if (isLoggedIn &&
          isAuthRoute &&
          loc != MintflowRoutes.onboarding &&
          loc != MintflowRoutes.resetPassword &&
          onboarded != false) {
        return MintflowRoutes.dashboard;
      }
      return null;
    },
    routes: [
      // ── Pre-auth ──────────────────────────────────────────────────────────
      GoRoute(
          path: MintflowRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: MintflowRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: MintflowRoutes.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: MintflowRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),

      // ── Forgot password flow (no bottom nav) ─────────────────────────────
      GoRoute(
        path: MintflowRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: MintflowRoutes.checkEmail,
        builder: (_, state) => CheckEmailScreen(
          email: (state.extra as String?) ?? '',
        ),
      ),
      GoRoute(
        path: MintflowRoutes.resetPassword,
        builder: (_, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ??
              (state.extra is String ? state.extra as String : null),
        ),
      ),

      // ── Main shell ────────────────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => MintflowShell(child: child),
        routes: [
          GoRoute(
              path: MintflowRoutes.dashboard,
              builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: MintflowRoutes.transactions,
            builder: (_, __) => const TransactionListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, __) => const AddTransactionScreen(),
              ),
            ],
          ),
          GoRoute(
            path: MintflowRoutes.goals,
            builder: (_, __) => const GoalsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, __) => const AddGoalScreen(),
              ),
            ],
          ),
          GoRoute(
            path: MintflowRoutes.bills,
            builder: (_, __) => const BillsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, __) => const AddBillScreen(),
              ),
            ],
          ),
          GoRoute(
              path: MintflowRoutes.insights,
              builder: (_, __) => const InsightsScreen()),
          GoRoute(
              path: MintflowRoutes.settings,
              builder: (_, __) => const SettingsScreen()),
          GoRoute(
              path: MintflowRoutes.profile,
              builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ── Full-screen overlays (no bottom nav) ──────────────────────────────
      GoRoute(
        path: MintflowRoutes.paywall,
        builder: (_, state) => PaywallScreen(
          feature: state.uri.queryParameters['feature'],
        ),
      ),
      GoRoute(
        path: MintflowRoutes.notifications,
        builder: (_, __) => const InAppNotificationsScreen(),
      ),
      GoRoute(
        path: MintflowRoutes.notificationSettings,
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: MintflowRoutes.linkedAccounts,
        builder: (_, __) => const LinkedAccountsScreen(),
      ),
      GoRoute(
        path: MintflowRoutes.exportData,
        builder: (_, __) => const ExportDataScreen(),
      ),
      GoRoute(
        path: MintflowRoutes.privacySecurity,
        builder: (_, __) => const PrivacySecurityScreen(),
      ),
      GoRoute(
        path: MintflowRoutes.recurringSubscriptions,
        builder: (_, __) => const RecurringSubscriptionsScreen(),
      ),
    ],
  );
}

// ── Shell ─────────────────────────────────────────────────────────────────────

class MintflowShell extends StatelessWidget {
  final Widget child;
  const MintflowShell({super.key, required this.child});

  static const _tabs = [
    MintflowRoutes.dashboard,
    MintflowRoutes.transactions,
    MintflowRoutes.insights,
    MintflowRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: child,
      // bottomNavigationBar: _BottomNav(
      //   currentIndex: currentIndex < 0 ? 0 : currentIndex,
      //   onTap: (i) => context.go(_tabs[i]),
      // ),
      bottomNavigationBar: _MintflowNavBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        onTap: (i) => context.go(_tabs[i]),
      ),
      floatingActionButton: _showFab(location)
          ? _Fab(
              onPressed: () => context.push(MintflowRoutes.addTx),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  bool _showFab(String loc) =>
      loc == MintflowRoutes.dashboard || loc == MintflowRoutes.transactions;
}

class _Fab extends StatelessWidget {
  final VoidCallback onPressed;
  const _Fab({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF2EAD6A),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2EAD6A).withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

const _navItems = [
  _NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  _NavItem(
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
    label: 'Transactions',
  ),
  _NavItem(
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    label: 'Insights',
  ),
  _NavItem(
    icon: Icons.person_outline,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];

class _MintflowNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MintflowNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: MintflowColors.card(context),
        border: Border(
          top: BorderSide(color: MintflowColors.hairline(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
                MintflowColors.isDark(context) ? 0.35 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left two items
              ...[0, 1].map(
                (i) => Expanded(
                  child: _NavBarItem(
                    item: _navItems[i],
                    isActive: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
              ),

              // Center Add button
              // SizedBox(
              //   width: 72,
              //   child: Center(
              //     child: GestureDetector(
              //       onTap: onAddTap,
              //       child: _AddButton(),
              //     ),
              //   ),
              // ),

              // Right two items
              ...[2, 3].map(
                (i) => Expanded(
                  child: _NavBarItem(
                    item: _navItems[i],
                    isActive: currentIndex == i,
                    onTap: () => onTap(i),
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

class _NavBarItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _slideAnim = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    if (widget.isActive) _controller.forward();
  }

  @override
  void didUpdateWidget(_NavBarItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      widget.isActive ? _controller.forward() : _controller.reverse();
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
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.isActive ? widget.item.activeIcon : widget.item.icon,
                    key: ValueKey(widget.isActive),
                    size: 22,
                    color: widget.isActive
                        ? MintflowColors.green500
                        : MintflowColors.textTertiary(context),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: MintflowTextStyles.overline.copyWith(
                    color: widget.isActive
                        ? MintflowColors.green500
                        : MintflowColors.textTertiary(context),
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: Text(widget.item.label),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: widget.isActive ? 18 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: MintflowColors.green400,
                    borderRadius: BorderRadius.circular(2),
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

class _AddButton extends StatefulWidget {
  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnim;
  late Animation<double> _scaleAnim;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotateAnim = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: Transform.rotate(
            angle: _rotateAnim.value * 2 * math.pi,
            child: child,
          ),
        ),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintflowColors.green400, MintflowColors.green600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MintflowColors.green400.withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: MintflowColors.green400.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: -2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _StubScreen extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StubScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: MintflowColors.ink30),
            const SizedBox(height: 12),
            Text(
              label,
              style: MintflowTextStyles.displaySmall.copyWith(
                color: MintflowColors.ink60,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coming soon',
              style: MintflowTextStyles.bodyMedium.copyWith(
                color: MintflowColors.ink30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTransactionSheet extends StatelessWidget {
  const _AddTransactionSheet();

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
            'Add Transaction',
            style: MintflowTextStyles.displaySmall.copyWith(
              color: MintflowColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This screen is coming soon.',
            style: MintflowTextStyles.bodyMedium.copyWith(
              color: MintflowColors.ink60,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}
