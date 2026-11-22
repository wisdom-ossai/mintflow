import 'package:mintflow_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  // export ErrorBanner
  final String message;
  const ErrorBanner({super.key, required this.message});
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: message,
        child: Container(
          margin: const EdgeInsets.only(bottom: MintflowSpacing.lg),
          padding: const EdgeInsets.all(MintflowSpacing.md),
          decoration: BoxDecoration(
            color: MintflowColors.redWash(context),
            borderRadius: MintflowRadius.md_,
            border:
                Border.all(color: MintflowColors.red.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline,
                color: MintflowColors.red, size: 16),
            const SizedBox(width: MintflowSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: MintflowTextStyles.bodySmall
                    .copyWith(color: MintflowColors.red),
              ),
            ),
          ]),
        ),
      );
}
