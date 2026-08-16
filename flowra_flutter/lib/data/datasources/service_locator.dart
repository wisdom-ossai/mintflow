import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/api_client.dart';
import '../repositories/repositories.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service Locator — single instance of every dependency.
// Call ServiceLocator.init() once in main() after Supabase is ready.
// Access anywhere via ServiceLocator.instance.
// ─────────────────────────────────────────────────────────────────────────────

class ServiceLocator {
  ServiceLocator._();
  static ServiceLocator? _instance;
  static ServiceLocator get instance {
    assert(_instance != null, 'Call ServiceLocator.init() first');
    return _instance!;
  }

  late final FlowraApiClient api;
  late final UserRepository users;
  late final DashboardRepository dashboard;
  late final TransactionRepository transactions;
  late final GoalRepository goals;
  late final BillRepository bills;
  late final InsightRepository insights;

  static Future<void> init() async {
    final sl = ServiceLocator._();

    // Storage — reads Supabase JWT automatically after login
    const storage = FlutterSecureStorage();

    // Seed the JWT from the current Supabase session on startup
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await storage.write(
        key: 'access_token',
        value: session.accessToken,
      );
    }

    // Listen for future session changes and keep the token in sync
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final token = data.session?.accessToken;
      if (token != null) {
        await storage.write(key: 'access_token', value: token);
      } else {
        await storage.delete(key: 'access_token');
      }
    });

    sl.api = FlowraApiClient(storage: storage);
    sl.users = UserRepository(sl.api);
    sl.dashboard = DashboardRepository(sl.api);
    sl.transactions = TransactionRepository(sl.api);
    sl.goals = GoalRepository(sl.api);
    sl.bills = BillRepository(sl.api);
    sl.insights = InsightRepository(sl.api);

    _instance = sl;
  }
}
