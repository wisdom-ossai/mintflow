import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';

class InAppNotificationsScreen extends StatelessWidget {
  const InAppNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        title: Text(
          'Notifications',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push(MintflowRoutes.notificationSettings),
            icon: const Icon(Icons.tune_rounded, color: MintflowColors.cream),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MintBreakpoints.pageGutter(context),
          ),
          child: MintAdaptiveWidth(
            maxWidth: MintBreakpoints.formMax,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: MintflowColors.softFill(context),
                    borderRadius: MintflowRadius.xl_,
                    border:
                        Border.all(color: MintflowColors.hairline(context)),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: MintflowColors.textSecondary(context),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: MintflowTextStyles.labelLarge
                      .copyWith(color: MintflowColors.textPrimary(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'New alerts and reminders will show up here.',
                  style: MintflowTextStyles.bodySmall
                      .copyWith(color: MintflowColors.textSecondary(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: () =>
                      context.push(MintflowRoutes.notificationSettings),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Manage notification settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
