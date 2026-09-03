import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class InAppNotificationsScreen extends StatelessWidget {
  const InAppNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      appBar: AppBar(
        backgroundColor: FlowraColors.green900,
        title: Text(
          'Notifications',
          style: FlowraTextStyles.displaySmall.copyWith(color: FlowraColors.cream),
        ),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            onPressed: () => context.push(FlowraRoutes.notificationSettings),
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: FlowraRadius.xl_,
                  border: Border.all(color: FlowraColors.ink10),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: FlowraColors.ink60,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: FlowraTextStyles.labelLarge.copyWith(color: FlowraColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'New alerts and reminders will show up here.',
                style: FlowraTextStyles.bodySmall.copyWith(color: FlowraColors.ink60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: () => context.push(FlowraRoutes.notificationSettings),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Manage notification settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
