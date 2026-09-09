import 'package:flutter/foundation.dart';

/// Signals auth/session events so go_router can redirect (e.g. on API 401).
class AuthGate {
  AuthGate._();

  /// True when access or refresh tokens are present in secure storage.
  static final ValueNotifier<bool> isAuthenticated = ValueNotifier(false);

  /// Bumped when the API clears tokens after a failed refresh — router refresh.
  static final ValueNotifier<int> unauthorizedTick = ValueNotifier(0);

  /// Optional: user profile loaded; used by splash/redirect for onboarding.
  static final ValueNotifier<bool?> onboardingComplete = ValueNotifier(null);

  static void setAuthenticated(bool value) {
    if (isAuthenticated.value != value) {
      isAuthenticated.value = value;
    }
    if (!value) {
      onboardingComplete.value = null;
    }
  }

  static void notifyUnauthorized() {
    onboardingComplete.value = null;
    isAuthenticated.value = false;
    unauthorizedTick.value++;
  }

  static void setOnboardingComplete(bool complete) {
    onboardingComplete.value = complete;
  }
}
