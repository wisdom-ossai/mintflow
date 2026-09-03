import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// True only after a successful [Purchases.configure]. Native SDK calls
/// crash fatally if invoked before configure — Dart try/catch cannot catch that.
bool revenueCatConfigured = false;

Future<void> configureRevenueCat({String? appUserId}) async {
  const fromDefine = String.fromEnvironment('REVENUECAT_API_KEY');
  final apiKey = fromDefine.isNotEmpty
      ? fromDefine
      : (dotenv.env['REVENUECAT_API_KEY'] ?? '');
  if (apiKey.isEmpty) {
    revenueCatConfigured = false;
    debugPrint('⚠️ RevenueCat API key missing — paywall purchases disabled');
    return;
  }
  try {
    final config = PurchasesConfiguration(apiKey);
    if (appUserId != null && appUserId.isNotEmpty) {
      config.appUserID = appUserId;
    }
    await Purchases.configure(config);
    revenueCatConfigured = true;
  } catch (e) {
    revenueCatConfigured = false;
    debugPrint('⚠️ RevenueCat configure failed: $e');
  }
}

/// Call after login / splash when we know the Flowra user id.
Future<void> identifyRevenueCat(String userId) async {
  if (!revenueCatConfigured) return;
  try {
    await Purchases.logIn(userId);
  } catch (_) {}
}
