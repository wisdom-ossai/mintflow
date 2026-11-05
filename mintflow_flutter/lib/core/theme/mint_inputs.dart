import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared [InputDecoration] that keeps labelText associated for screen readers.
InputDecoration mintInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  Widget? suffixIcon,
  Color? fillColor,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor ?? MintflowColors.card(context),
  );
}
