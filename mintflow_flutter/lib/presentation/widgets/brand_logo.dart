import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Mintflow brand logo mark.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? wordmarkColor;
  final double gap;

  const BrandLogo({
    super.key,
    this.size = 40,
    this.showWordmark = false,
    this.wordmarkColor,
    this.gap = 10,
  });

  static const assetPath = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        cacheWidth: (size * 3).round().clamp(48, 512),
        cacheHeight: (size * 3).round().clamp(48, 512),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: gap),
        Text(
          'Mintflow',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: size * 0.55,
            fontWeight: FontWeight.w500,
            color: wordmarkColor ?? MintflowColors.green900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
