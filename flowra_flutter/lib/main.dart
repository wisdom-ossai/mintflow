import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/datasources/local_cache.dart';
import 'data/datasources/service_locator.dart';
import 'presentation/cubits/cubits.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flowra — main.dart
// Entry point. Initializes Supabase, Firebase, RevenueCat, and Cubits.
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

  final supabaseUrl = (dotenv.env['SUPABASE_URL'] ?? '').trim();
  final supabaseAnon = (dotenv.env['SUPABASE_ANON_KEY'] ?? '').trim();
  if (supabaseUrl.isEmpty || supabaseAnon.isEmpty) {
    debugPrint(
      '❌ SUPABASE_URL / SUPABASE_ANON_KEY missing. '
      'Copy them from Supabase → Settings → API into flowra_flutter/.env, '
      'then fully stop and re-run (hot reload does not reload .env assets).',
    );
  } else {
    debugPrint('Supabase URL: $supabaseUrl');
  }

  await FlowraCache.init();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase config may not be present in dev — non-fatal
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnon,
  );

  await ServiceLocator.init();
  await _configureRevenueCat();

  runApp(const FlowraApp());
}

Future<void> _configureRevenueCat() async {
  const fromDefine = String.fromEnvironment('REVENUECAT_API_KEY');
  final apiKey = fromDefine.isNotEmpty
      ? fromDefine
      : (dotenv.env['REVENUECAT_API_KEY'] ?? '');
  if (apiKey.isEmpty) {
    debugPrint('⚠️ RevenueCat API key missing — paywall purchases disabled');
    return;
  }
  try {
    final config = PurchasesConfiguration(apiKey);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) config.appUserID = uid;
    await Purchases.configure(config);
  } catch (e) {
    debugPrint('⚠️ RevenueCat configure failed: $e');
  }
}

class FlowraApp extends StatefulWidget {
  const FlowraApp({super.key});

  @override
  State<FlowraApp> createState() => _FlowraAppState();
}

class _FlowraAppState extends State<FlowraApp> {
  late final GoRouter _router;
  late final DashboardCubit _dashboardCubit;
  late final TransactionCubit _transactionCubit;
  late final InsightCubit _insightCubit;
  late final UserCubit _userCubit;
  late final GoalCubit _goalCubit;
  late final BillCubit _billCubit;

  @override
  void initState() {
    super.initState();
    _dashboardCubit = DashboardCubit();
    _transactionCubit = TransactionCubit();
    _insightCubit = InsightCubit();
    _userCubit = UserCubit();
    _goalCubit = GoalCubit();
    _billCubit = BillCubit();
    _router = buildRouter();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _router.go(FlowraRoutes.resetPassword);
      }
      if (data.event == AuthChangeEvent.signedIn) {
        final uid = data.session?.user.id;
        if (uid != null) {
          try {
            await Purchases.logIn(uid);
          } catch (_) {}
        }
        _registerFcmToken();
      }
      if (data.event == AuthChangeEvent.signedOut) {
        AuthGate.setOnboardingComplete(false);
        AuthGate.onboardingComplete.value = null;
      }
    });

    // 401 from API → login
    AuthGate.unauthorizedTick.addListener(() {
      if (_router.routerDelegate.currentConfiguration.uri.path !=
          FlowraRoutes.login) {
        _router.go(FlowraRoutes.login);
      }
    });

    _registerFcmToken();
  }

  Future<void> _registerFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null &&
          Supabase.instance.client.auth.currentSession != null) {
        await _userCubit.updateFirebaseToken(token);
      }
    } catch (_) {
      // FCM unavailable in simulators / missing Firebase config
    }
  }

  @override
  void dispose() {
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
        BlocProvider.value(value: _dashboardCubit),
        BlocProvider.value(value: _transactionCubit),
        BlocProvider.value(value: _insightCubit),
        BlocProvider.value(value: _userCubit),
        BlocProvider.value(value: _goalCubit),
        BlocProvider.value(value: _billCubit),
      ],
      child: MaterialApp.router(
        title: 'Flowra',
        debugShowCheckedModeBanner: false,
        theme: FlowraTheme.light,
        darkTheme: FlowraTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
