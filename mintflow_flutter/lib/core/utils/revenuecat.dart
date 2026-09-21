import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// True only after a successful [Purchases.configure]. Native SDK calls
/// crash fatally if invoked before configure — Dart try/catch cannot catch that.
bool revenueCatConfigured = false;

String _env(String key) => (dotenv.env[key] ?? '').trim();

/// Public SDK key: `goog_` (Android Play), `appl_` (iOS App Store), `test_` (sandbox).
String _resolveApiKey() {
  const defineAndroid = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  const defineIos = String.fromEnvironment('REVENUECAT_IOS_KEY');
  const defineAny = String.fromEnvironment('REVENUECAT_API_KEY');

  if (defaultTargetPlatform == TargetPlatform.android) {
    if (defineAndroid.isNotEmpty) return defineAndroid;
    final fromEnv = _env('REVENUECAT_ANDROID_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
  } else if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    if (defineIos.isNotEmpty) return defineIos;
    final fromEnv = _env('REVENUECAT_IOS_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
  }

  if (defineAny.isNotEmpty) return defineAny;
  return _env('REVENUECAT_API_KEY');
}

Future<void> configureRevenueCat({String? appUserId}) async {
  final apiKey = _resolveApiKey();
  if (apiKey.isEmpty) {
    revenueCatConfigured = false;
    debugPrint('⚠️ RevenueCat API key missing — paywall purchases disabled');
    return;
  }

  // RevenueCat's native SDK shows "Wrong API Key" and kills a release
  // process if configured with a test_ key. Skip rather than crash; the
  // paywall already handles revenueCatConfigured == false.
  if (kReleaseMode && apiKey.startsWith('test_')) {
    revenueCatConfigured = false;
    debugPrint(
      '⚠️ RevenueCat test key cannot be used in a release APK/IPA. '
      'Skipping configure. Set a goog_/appl_ production key for IAP.',
    );
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

/// Call after login / splash when we know the Mintflow user id.
Future<void> identifyRevenueCat(String userId) async {
  if (!revenueCatConfigured) return;
  try {
    await Purchases.logIn(userId);
  } catch (_) {}
}
