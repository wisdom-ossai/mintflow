import 'package:flutter/material.dart';

/// Motion helpers that honor the system Reduce Motion / Remove animations setting.
class MintMotion {
  MintMotion._();

  static bool reduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration duration(
    BuildContext context,
    Duration normal, {
    Duration reduced = Duration.zero,
  }) =>
      reduce(context) ? reduced : normal;

  static Curve curve(
    BuildContext context, {
    Curve normal = Curves.easeOutCubic,
    Curve reduced = Curves.linear,
  }) =>
      reduce(context) ? reduced : normal;

  /// Soften decorative bounce/elastic into a calm ease-out when motion is allowed.
  static Curve softOut(BuildContext context) =>
      reduce(context) ? Curves.linear : Curves.easeOutCubic;

  static Future<void> maybeDelay(
    BuildContext context,
    Duration delay,
  ) async {
    if (reduce(context) || delay == Duration.zero) return;
    await Future<void>.delayed(delay);
  }
}
