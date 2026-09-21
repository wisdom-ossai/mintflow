import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow Local Cache
// Replaces hive_flutter. Uses shared_preferences for lightweight JSON caching.
// Purpose: reduce API calls for frequently-read, slow-changing data.
//
// Strategy:
//   - Dashboard summary: cached 15 minutes (invalidated on new transaction)
//   - Goals list: cached 5 minutes
//   - Bills + payments: cached 5 minutes (invalidated on mark-paid)
//   - User profile: cached until explicit refresh
//   - JWT token: stored in FlutterSecureStorage (not here — sensitive)
// ─────────────────────────────────────────────────────────────────────────────

class MintflowCache {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    assert(_prefs != null, 'MintflowCache.init() must be called before use');
    return _prefs!;
  }

  // ── Generic read/write with TTL ───────────────────────────────────────────

  static Future<void> set(
    String key,
    dynamic value, {
    Duration ttl = const Duration(minutes: 15),
  }) async {
    final entry = {
      'data': value,
      'expires': DateTime.now().add(ttl).millisecondsSinceEpoch,
    };
    await _p.setString(key, jsonEncode(entry));
  }

  static T? get<T>(String key) {
    final raw = _p.getString(key);
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expires = entry['expires'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expires) {
        _p.remove(key); // expired — clean up
        return null;
      }
      return entry['data'] as T?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(String key) => _p.remove(key);

  // ── Invalidation helpers ──────────────────────────────────────────────────

  /// Call after creating/updating/deleting any transaction.
  static Future<void> invalidateDashboard() async {
    await Future.wait([
      _p.remove(CacheKeys.dashboardSummary),
      _p.remove(CacheKeys.transactions),
    ]);
  }

  /// Call after marking a bill paid or adding a new bill.
  static Future<void> invalidateBills() async {
    await Future.wait([
      _p.remove(CacheKeys.bills),
      _p.remove(CacheKeys.billPayments),
      _p.remove(CacheKeys.dashboardSummary), // upcoming bills strip updates
    ]);
  }

  /// Call after adding/updating a savings goal.
  static Future<void> invalidateGoals() async {
    await _p.remove(CacheKeys.goals);
  }

  /// Non-expiring preference (budget method, monthly savings target, etc.).
  static Future<void> setPref(String key, String value) =>
      _p.setString('pref_$key', value);

  static String? getPref(String key) => _p.getString('pref_$key');

  static Future<void> setPrefDouble(String key, double value) =>
      _p.setDouble('pref_$key', value);

  static double? getPrefDouble(String key) => _p.getDouble('pref_$key');

  /// Call on logout — clears all cached data.
  static Future<void> clearAll() async {
    final keys = _p.getKeys().where((k) => k.startsWith('mintflow_')).toList();
    await Future.wait(keys.map(_p.remove));
  }
}

// ── Cache key constants ───────────────────────────────────────────────────────

class CacheKeys {
  CacheKeys._();

  static const dashboardSummary = 'mintflow_dashboard_summary';
  static const transactions = 'mintflow_transactions_p1'; // first page only
  static const accounts = 'mintflow_accounts';
  static const goals = 'mintflow_goals';
  static const bills = 'mintflow_bills';
  static const billPayments = 'mintflow_bill_payments';
  static const userProfile = 'mintflow_user_profile';
  static const categories = 'mintflow_categories';
  static const notifPrefs = 'mintflow_notif_prefs';

  // Insight cache — keyed by period e.g. "mintflow_insight_2025-11"
  static String insight(String periodKey) => 'mintflow_insight_$periodKey';

  // Debt plan
  static const debtPlan = 'mintflow_debt_plan';

  // Financial profile preferences
  static const budgetMethod = 'budget_method';
  static const monthlySavingsTarget = 'monthly_savings_target';
  static const biometricLock = 'biometric_lock';
  static const themeMode = 'theme_mode';
}
