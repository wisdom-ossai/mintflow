import 'package:mintflow_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  // export ErrorBanner
  final String message;
  const ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintflowColors.redWash(context),
          borderRadius: MintflowRadius.md_,
          border: Border.all(color: MintflowColors.red.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: MintflowColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: MintflowTextStyles.bodySmall
                      .copyWith(color: MintflowColors.red))),
        ]),
      );
}
