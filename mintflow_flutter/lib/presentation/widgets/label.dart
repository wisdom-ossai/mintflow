import 'package:mintflow_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Visual field caption. Prefer [mintInputDecoration] `labelText` for a11y;
/// keep this only when a separate overline above the field is intentional.
class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: MintflowTextStyles.labelMedium.copyWith(
          color: MintflowColors.textSecondary(context),
          fontWeight: FontWeight.w600,
        ),
      );
}
