import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-page / inline error with retry and live-region announcement.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  final Color? foreground;
  final bool compact;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
    this.foreground,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? MintflowColors.textPrimary(context);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(
            compact ? MintflowSpacing.lg : MintflowSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: color.withValues(alpha: 0.7),
                size: compact ? 28 : 36,
              ),
              const SizedBox(height: MintflowSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: MintflowTextStyles.bodyMedium.copyWith(color: color),
              ),
              const SizedBox(height: MintflowSpacing.lg),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
