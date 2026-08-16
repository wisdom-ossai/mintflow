import 'package:flowra_flutter/core/theme/app_theme.dart';
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
          color: FlowraColors.redSoft,
          borderRadius: FlowraRadius.md_,
          border: Border.all(color: FlowraColors.red.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: FlowraColors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: FlowraTextStyles.bodySmall
                      .copyWith(color: FlowraColors.red))),
        ]),
      );
}
