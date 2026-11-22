import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared empty surface: icon + message + optional primary CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? iconBg;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? MintflowColors.textSecondary(context);
    final bg = iconBg ?? MintflowColors.softFill(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MintflowSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: MintflowRadius.xl_,
                border: Border.all(color: MintflowColors.hairline(context)),
              ),
              child: Icon(icon, color: tint, size: 32),
            ),
            const SizedBox(height: MintflowSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MintflowTextStyles.labelLarge.copyWith(
                color: MintflowColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: MintflowSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MintflowTextStyles.bodySmall.copyWith(
                color: MintflowColors.textSecondary(context),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: MintflowSpacing.xl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
