import 'package:flutter/material.dart';

/// Mintflow brand logo mark (M icon asset).
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
        filterQuality: FilterQuality.high,
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
            color: wordmarkColor ?? const Color(0xFF05122B),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
