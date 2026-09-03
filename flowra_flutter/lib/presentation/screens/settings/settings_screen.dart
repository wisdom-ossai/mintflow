import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../data/datasources/service_locator.dart';
import '../../cubits/cubits.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        final user = state is UserLoaded ? state.user : null;
        final name = user?.displayName ?? 'User';
        final email = user?.email ?? '';
        final tierLabel = user?.effectiveTier.name ?? 'seed';
        return Scaffold(
          backgroundColor: FlowraColors.cream,
          appBar: AppBar(
            backgroundColor: FlowraColors.green900,
            title: Text('Settings',
                style: FlowraTextStyles.displaySmall
                    .copyWith(color: FlowraColors.cream)),
          ),
          body: ListView(children: [
            // Profile card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: FlowraRadius.xl_,
                border: Border.all(color: FlowraColors.ink10),
              ),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: FlowraColors.green400,
                    borderRadius: FlowraRadius.lg_,
                  ),
                  child: Center(
                      child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: FlowraTextStyles.displaySmall
                        .copyWith(color: Colors.white, fontSize: 20),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: FlowraTextStyles.labelLarge),
                    Text(email,
                        style: FlowraTextStyles.bodySmall
                            .copyWith(color: FlowraColors.ink60)),
                  ],
                )),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlowraColors.purple.withOpacity(0.1),
                    borderRadius: FlowraRadius.pill_,
                  ),
                  child: Text(
                    tierLabel[0].toUpperCase() + tierLabel.substring(1),
                    style: FlowraTextStyles.overline.copyWith(
                        color: FlowraColors.purple,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),

            _Section('Account', [
              _Tile(Icons.person_outline, 'Edit profile', () {}),
              _Tile(Icons.lock_outline, 'Change password', () {}),
              _Tile(Icons.notifications_outlined, 'Notifications',
                  () => context.push(FlowraRoutes.notificationSettings)),
              _Tile(Icons.currency_exchange, 'Currency and locale', () {}),
            ]),
            _Section('Subscription', [
              _Tile(Icons.star_outline, 'Manage plan',
                  () => context.push(FlowraRoutes.paywall),
                  trailing: tierLabel[0].toUpperCase() + tierLabel.substring(1)),
              _Tile(Icons.download_outlined, 'Export data (CSV)', () {}),
            ]),
            _Section('About', [
              _Tile(Icons.privacy_tip_outlined, 'Privacy policy', () {}),
              _Tile(Icons.description_outlined, 'Terms of service', () {}),
              _Tile(Icons.info_outline, 'App version', () {},
                  trailing: '1.0.0'),
            ]),

            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlowraColors.red,
                  side: BorderSide(color: FlowraColors.red.withOpacity(0.5)),
                ),
                onPressed: () async {
                  try {
                    await ServiceLocator.instance.api.logout();
                  } catch (_) {
                    await ServiceLocator.instance.tokens.clear();
                  }
                  AuthGate.onboardingComplete.value = null;
                  if (context.mounted) context.go(FlowraRoutes.login);
                },
                child: const Text('Sign out'),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> tiles;
  const _Section(this.title, this.tiles);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(title.toUpperCase(),
                style: FlowraTextStyles.overline
                    .copyWith(color: FlowraColors.ink60)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: FlowraRadius.xl_,
              border: Border.all(color: FlowraColors.ink10),
            ),
            child: Column(
              children: tiles
                  .asMap()
                  .entries
                  .map((e) => Column(children: [
                        e.value,
                        if (e.key < tiles.length - 1)
                          Divider(height: 1, color: FlowraColors.ink10),
                      ]))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;
  const _Tile(this.icon, this.label, this.onTap, {this.trailing});
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: FlowraColors.ink60),
        title: Text(label,
            style: FlowraTextStyles.bodySmall
                .copyWith(fontWeight: FontWeight.w500)),
        trailing: trailing != null
            ? Text(trailing!,
                style: FlowraTextStyles.labelSmall
                    .copyWith(color: FlowraColors.ink60))
            : Icon(Icons.chevron_right, size: 18, color: FlowraColors.ink30),
        onTap: onTap,
      );
}
