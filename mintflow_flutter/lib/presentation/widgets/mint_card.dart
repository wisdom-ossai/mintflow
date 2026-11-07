import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Flat hairline card used across Mintflow surfaces.
class MintCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const MintCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? MintflowRadius.lg_;
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(MintflowSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? MintflowColors.card(context),
        borderRadius: radius,
        border: Border.all(color: MintflowColors.hairline(context)),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
