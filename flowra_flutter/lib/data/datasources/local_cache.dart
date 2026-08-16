import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flowra Local Cache
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

class FlowraCache {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    assert(_prefs != null, 'FlowraCache.init() must be called before use');
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

  /// Call on logout — clears all cached data.
  static Future<void> clearAll() async {
    final keys = _p.getKeys().where((k) => k.startsWith('flowra_')).toList();
    await Future.wait(keys.map(_p.remove));
  }
}

// ── Cache key constants ───────────────────────────────────────────────────────

class CacheKeys {
  CacheKeys._();

  static const dashboardSummary = 'flowra_dashboard_summary';
  static const transactions = 'flowra_transactions_p1'; // first page only
  static const accounts = 'flowra_accounts';
  static const goals = 'flowra_goals';
  static const bills = 'flowra_bills';
  static const billPayments = 'flowra_bill_payments';
  static const userProfile = 'flowra_user_profile';
  static const categories = 'flowra_categories';
  static const notifPrefs = 'flowra_notif_prefs';

  // Insight cache — keyed by period e.g. "flowra_insight_2025-11"
  static String insight(String periodKey) => 'flowra_insight_$periodKey';

  // Debt plan
  static const debtPlan = 'flowra_debt_plan';
}
