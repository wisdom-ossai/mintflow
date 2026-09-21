import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/router/app_router.dart';
import 'core/utils/revenuecat.dart';
import 'data/datasources/local_cache.dart';
import 'data/datasources/service_locator.dart';
import 'presentation/cubits/cubits.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow — main.dart
// Entry point. Initializes dotenv, Firebase, RevenueCat, and Cubits.
// Auth session = tokens in FlutterSecureStorage (FastAPI JWT).
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('⚠️ Failed to load .env file: $e');
  }

  await MintflowCache.init();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase config may not be present in dev — non-fatal
  }

  await ServiceLocator.init();
  await configureRevenueCat();

  runApp(const MintflowApp());
}

class MintflowApp extends StatefulWidget {
  const MintflowApp({super.key});

  @override
  State<MintflowApp> createState() => _MintflowAppState();
}

class _MintflowAppState extends State<MintflowApp> {
  late final GoRouter _router;
  late final ThemeCubit _themeCubit;
  late final DashboardCubit _dashboardCubit;
  late final TransactionCubit _transactionCubit;
  late final InsightCubit _insightCubit;
  late final UserCubit _userCubit;
  late final GoalCubit _goalCubit;
  late final BillCubit _billCubit;

  @override
  void initState() {
    super.initState();
    _themeCubit = ThemeCubit();
    _dashboardCubit = DashboardCubit();
    _transactionCubit = TransactionCubit();
    _insightCubit = InsightCubit();
    _userCubit = UserCubit();
    _goalCubit = GoalCubit();
    _billCubit = BillCubit();
    _router = buildRouter();

    // 401 from API (failed refresh) → login
    AuthGate.unauthorizedTick.addListener(() {
      if (_router.routerDelegate.currentConfiguration.uri.path !=
          MintflowRoutes.login) {
        _router.go(MintflowRoutes.login);
      }
    });

    // After splash loads user, identify RevenueCat + FCM
    _userCubit.stream.listen((state) {
      if (state is UserLoaded) {
        identifyRevenueCat(state.user.id);
        _registerFcmToken();
      }
    });

    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null && AuthGate.isAuthenticated.value) {
        await _userCubit.updateFirebaseToken(token);
      }
    } catch (_) {
      // FCM unavailable in simulators / missing Firebase config
    }
  }

  @override
  void dispose() {
    _themeCubit.close();
    _dashboardCubit.close();
    _transactionCubit.close();
    _insightCubit.close();
    _userCubit.close();
    _goalCubit.close();
    _billCubit.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _themeCubit),
        BlocProvider.value(value: _dashboardCubit),
        BlocProvider.value(value: _transactionCubit),
        BlocProvider.value(value: _insightCubit),
        BlocProvider.value(value: _userCubit),
        BlocProvider.value(value: _goalCubit),
        BlocProvider.value(value: _billCubit),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, mode) {
          return MaterialApp.router(
            title: 'Mintflow',
            debugShowCheckedModeBanner: false,
            theme: MintflowTheme.light,
            darkTheme: MintflowTheme.dark,
            themeMode: mode,
            routerConfig: _router,
            builder: (context, child) {
              final dark =
                  Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  // Navy headers stay readable; Android nav bar follows theme.
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                  systemNavigationBarColor: dark
                      ? MintflowColors.darkCard
                      : Colors.white,
                  systemNavigationBarIconBrightness:
                      dark ? Brightness.light : Brightness.dark,
                  systemNavigationBarDividerColor: Colors.transparent,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
