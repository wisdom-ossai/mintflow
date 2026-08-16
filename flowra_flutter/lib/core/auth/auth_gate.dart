import 'package:flutter/foundation.dart';

/// Signals auth/session events so go_router can redirect (e.g. on API 401).
class AuthGate {
  AuthGate._();

  /// Bumped when the API clears a token after 401 — router refreshListenable.
  static final ValueNotifier<int> unauthorizedTick = ValueNotifier(0);

  /// Optional: user profile loaded; used by splash/redirect for onboarding.
  static final ValueNotifier<bool?> onboardingComplete = ValueNotifier(null);

  static void notifyUnauthorized() {
    onboardingComplete.value = null;
    unauthorizedTick.value++;
  }

  static void setOnboardingComplete(bool complete) {
    onboardingComplete.value = complete;
  }
}
