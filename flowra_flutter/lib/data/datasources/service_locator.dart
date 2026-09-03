import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../datasources/api_client.dart';
import '../datasources/token_store.dart';
import '../repositories/repositories.dart';
import '../../core/auth/auth_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service Locator — single instance of every dependency.
// Call ServiceLocator.init() once in main() after dotenv is loaded.
// Access anywhere via ServiceLocator.instance.
// ─────────────────────────────────────────────────────────────────────────────

class ServiceLocator {
  ServiceLocator._();
  static ServiceLocator? _instance;
  static ServiceLocator get instance {
    assert(_instance != null, 'Call ServiceLocator.init() first');
    return _instance!;
  }

  late final FlutterSecureStorage storage;
  late final TokenStore tokens;
  late final FlowraApiClient api;
  late final UserRepository users;
  late final DashboardRepository dashboard;
  late final TransactionRepository transactions;
  late final GoalRepository goals;
  late final BillRepository bills;
  late final InsightRepository insights;

  static Future<void> init() async {
    final sl = ServiceLocator._();

    const storage = FlutterSecureStorage();
    sl.storage = storage;
    sl.tokens = TokenStore(storage: storage);

    AuthGate.setAuthenticated(await sl.tokens.hasTokens());

    sl.api = FlowraApiClient(tokenStore: sl.tokens);
    sl.users = UserRepository(sl.api);
    sl.dashboard = DashboardRepository(sl.api);
    sl.transactions = TransactionRepository(sl.api);
    sl.goals = GoalRepository(sl.api);
    sl.bills = BillRepository(sl.api);
    sl.insights = InsightRepository(sl.api);

    _instance = sl;
  }
}
