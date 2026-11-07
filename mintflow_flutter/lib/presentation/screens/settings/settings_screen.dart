import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/appearance_control.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../data/datasources/local_cache.dart';
import '../../cubits/cubits.dart';
import '../../widgets/mint_card.dart';

/// Preferences-only surface. Identity, money links, and danger live on Profile.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedCurrency = 'USD';
  String _selectedLanguage = 'English';

  static const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD'];
  static const _languages = ['English', 'Español', 'Français'];

  @override
  void initState() {
    super.initState();
    _selectedCurrency =
        MintflowCache.getPref(CacheKeys.displayCurrency) ?? 'USD';
    _selectedLanguage =
        MintflowCache.getPref(CacheKeys.displayLanguage) ?? 'English';
  }

  Future<void> _pick({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: MintBreakpoints.formMax),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: MintflowColors.page(ctx),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            MintflowSpacing.xxl,
            MintflowSpacing.xl,
            MintflowSpacing.xxl,
            MintflowSpacing.xxl + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: MintflowTextStyles.displaySmall),
              const SizedBox(height: MintflowSpacing.lg),
              ...options.map(
                (opt) => ListTile(
                  title: Text(opt),
                  trailing: opt == selected
                      ? const Icon(Icons.check_rounded,
                          color: MintflowColors.green500)
                      : null,
                  onTap: () => Navigator.pop(ctx, opt),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (chosen != null) onSelect(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Settings',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          vertical: MintflowSpacing.xl,
          horizontal: MintBreakpoints.pageGutter(context),
        ),
        children: [
          MintAdaptiveWidth(
            maxWidth: MintBreakpoints.formMax,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Appearance',
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: MintflowSpacing.sm),
                const MintCard(child: AppearanceControl()),
                const SizedBox(height: MintflowSpacing.xxl),
                Text(
                  'Preferences',
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: MintflowSpacing.sm),
                MintCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MintflowSpacing.lg,
                          vertical: MintflowSpacing.xs,
                        ),
                        leading: Icon(Icons.language_outlined,
                            color: MintflowColors.textSecondary(context)),
                        title: const Text('Language'),
                        trailing: Text(
                          _selectedLanguage,
                          style: MintflowTextStyles.labelMedium.copyWith(
                            color: MintflowColors.textSecondary(context),
                          ),
                        ),
                        onTap: () => _pick(
                          title: 'Language',
                          options: _languages,
                          selected: _selectedLanguage,
                          onSelect: (v) async {
                            setState(() => _selectedLanguage = v);
                            await MintflowCache.setPref(
                                CacheKeys.displayLanguage, v);
                          },
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: MintflowColors.hairline(context)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MintflowSpacing.lg,
                          vertical: MintflowSpacing.xs,
                        ),
                        leading: Icon(Icons.attach_money_rounded,
                            color: MintflowColors.textSecondary(context)),
                        title: const Text('Currency'),
                        trailing: Text(
                          _selectedCurrency,
                          style: MintflowTextStyles.labelMedium.copyWith(
                            color: MintflowColors.textSecondary(context),
                          ),
                        ),
                        onTap: () => _pick(
                          title: 'Currency',
                          options: _currencies,
                          selected: _selectedCurrency,
                          onSelect: (v) async {
                            setState(() => _selectedCurrency = v);
                            await MintflowCache.setPref(
                                CacheKeys.displayCurrency, v);
                          },
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: MintflowColors.hairline(context)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MintflowSpacing.lg,
                          vertical: MintflowSpacing.xs,
                        ),
                        leading: Icon(Icons.notifications_outlined,
                            color: MintflowColors.textSecondary(context)),
                        title: const Text('Notifications'),
                        subtitle: const Text('Push, reports, and alerts'),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: MintflowColors.textTertiary(context)),
                        onTap: () => context
                            .push(MintflowRoutes.notificationSettings),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MintflowSpacing.xxl),
                Text(
                  'Account',
                  style: MintflowTextStyles.overline.copyWith(
                    color: MintflowColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: MintflowSpacing.sm),
                MintCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MintflowSpacing.lg,
                          vertical: MintflowSpacing.xs,
                        ),
                        leading: Icon(Icons.security_outlined,
                            color: MintflowColors.textSecondary(context)),
                        title: const Text('Privacy & security'),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: MintflowColors.textTertiary(context)),
                        onTap: () =>
                            context.push(MintflowRoutes.privacySecurity),
                      ),
                      Divider(
                          height: 1,
                          color: MintflowColors.hairline(context)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: MintflowSpacing.lg,
                          vertical: MintflowSpacing.xs,
                        ),
                        leading: Icon(Icons.download_outlined,
                            color: MintflowColors.textSecondary(context)),
                        title: const Text('Export data'),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: MintflowColors.textTertiary(context)),
                        onTap: () =>
                            context.push(MintflowRoutes.exportData),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MintflowSpacing.xxl),
                BlocBuilder<UserCubit, UserState>(
                  builder: (context, state) {
                    final tier = state is UserLoaded
                        ? state.user.effectiveTier.name
                        : 'seed';
                    final label = tier[0].toUpperCase() + tier.substring(1);
                    return Text(
                      'Mintflow · $label · v1.0.0',
                      textAlign: TextAlign.center,
                      style: MintflowTextStyles.overline.copyWith(
                        color: MintflowColors.textTertiary(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
