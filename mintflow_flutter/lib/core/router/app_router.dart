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
import 'package:mintflow_flutter/core/theme/breakpoints.dart';
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
    final index = currentIndex < 0 ? 0 : currentIndex;
    final showFab = _showFab(location);
    final expanded = MintBreakpoints.isExpanded(context);

    if (expanded) {
      return Scaffold(
        backgroundColor: MintflowColors.page(context),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_tabs[i]),
              backgroundColor: MintflowColors.card(context),
              indicatorColor: MintflowColors.mintWash(context),
              selectedIconTheme:
                  const IconThemeData(color: MintflowColors.green500),
              unselectedIconTheme: IconThemeData(
                color: MintflowColors.textTertiary(context),
              ),
              selectedLabelTextStyle: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.green500,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: MintflowTextStyles.labelMedium.copyWith(
                color: MintflowColors.textTertiary(context),
              ),
              labelType: NavigationRailLabelType.all,
              leading: showFab
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: FloatingActionButton(
                        heroTag: 'mintflow_rail_fab',
                        onPressed: () => context.push(MintflowRoutes.addTx),
                        tooltip: 'Add transaction',
                        child: const Icon(Icons.add_rounded),
                      ),
                    )
                  : null,
              destinations: [
                for (final item in _navItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: MintflowColors.hairline(context),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          for (final item in _navItems)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: item.label,
            ),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              heroTag: 'mintflow_shell_fab',
              tooltip: 'Add transaction',
              onPressed: () => context.push(MintflowRoutes.addTx),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  bool _showFab(String loc) =>
      loc == MintflowRoutes.dashboard || loc == MintflowRoutes.transactions;
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

