import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../data/datasources/local_cache.dart';
import '../../../data/datasources/service_locator.dart';
import '../../cubits/cubits.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _biometricEnabled = false;
  bool _busy = false;

  static final _privacyUri = Uri.parse('https://mintflow.app/privacy');

  @override
  void initState() {
    super.initState();
    final stored = MintflowCache.getPref(CacheKeys.biometricLock);
    _biometricEnabled = stored == null ? true : stored == 'true';
  }

  Future<void> _setBiometric(bool value) async {
    setState(() => _biometricEnabled = value);
    await MintflowCache.setPref(
      CacheKeys.biometricLock,
      value ? 'true' : 'false',
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final ok = await launchUrl(_privacyUri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open privacy policy'),
          backgroundColor: MintflowColors.red,
        ),
      );
    }
  }

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
        title: Text('Sign out everywhere?',
            style: MintflowTextStyles.labelLarge),
        content: Text(
          'This ends all sessions on every device. You’ll need to sign in again here.',
          style: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.ink60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.ink60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out all',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ServiceLocator.instance.api.logoutAll();
      AuthGate.onboardingComplete.value = null;
      if (mounted) context.go(MintflowRoutes.login);
    } catch (e) {
      await ServiceLocator.instance.tokens.clear();
      AuthGate.onboardingComplete.value = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyAuthError(e)),
            backgroundColor: MintflowColors.red,
          ),
        );
        context.go(MintflowRoutes.login);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
        title: Text('Delete account?', style: MintflowTextStyles.labelLarge),
        content: Text(
          'This permanently deletes your account, linked banks, and all data. This cannot be undone.',
          style: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.ink60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.ink60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: MintflowTextStyles.labelMedium
                    .copyWith(color: MintflowColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final cubit = context.read<UserCubit>();
    final ok = await cubit.deleteAccount();
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      final err = cubit.state;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err is UserError ? err.message : 'Could not delete account',
          ),
          backgroundColor: MintflowColors.red,
        ),
      );
      return;
    }
    try {
      await ServiceLocator.instance.tokens.clear();
    } catch (_) {}
    AuthGate.onboardingComplete.value = null;
    if (!mounted) return;
    context.go(MintflowRoutes.login);
  }

  void _showChangePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.cream,
      appBar: AppBar(
        backgroundColor: MintflowColors.green900,
        foregroundColor: MintflowColors.cream,
        title: Text(
          'Privacy & security',
          style: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.cream),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Card(
              children: [
                _NavRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: MintflowColors.purple,
                  iconBg: MintflowColors.purpleSoft,
                  label: 'Change password',
                  subtitle: 'Update your sign-in password',
                  onTap: _showChangePassword,
                ),
                const _Hairline(),
                _NavRow(
                  icon: Icons.devices_rounded,
                  iconColor: MintflowColors.blue,
                  iconBg: MintflowColors.blueSoft,
                  label: 'Sign out all devices',
                  subtitle: 'End every active session',
                  onTap: _logoutAll,
                ),
                const _Hairline(),
                _ToggleRow(
                  icon: Icons.fingerprint_rounded,
                  iconColor: MintflowColors.green500,
                  iconBg: MintflowColors.green50,
                  label: 'Biometric lock',
                  subtitle: 'Prefer Face ID / Fingerprint on this device',
                  value: _biometricEnabled,
                  onChanged: _setBiometric,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.description_outlined,
                  iconColor: MintflowColors.ink60,
                  iconBg: MintflowColors.creamDark,
                  label: 'Privacy policy',
                  onTap: _openPrivacyPolicy,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Card(
              children: [
                _NavRow(
                  icon: Icons.delete_outline_rounded,
                  iconColor: MintflowColors.red,
                  iconBg: MintflowColors.redSoft,
                  label: 'Delete account',
                  subtitle: 'Permanently erase all data',
                  labelColor: MintflowColors.red,
                  onTap: _deleteAccount,
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(color: MintflowColors.green400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty) {
      setState(() => _error = 'Enter your current and new password');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    if (next != confirm) {
      setState(() => _error = 'New passwords do not match');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ServiceLocator.instance.api.changePassword(
        currentPassword: current,
        newPassword: next,
      );
      await ServiceLocator.instance.tokens.clear();
      AuthGate.onboardingComplete.value = null;
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Password updated. Please sign in again.'),
          backgroundColor: MintflowColors.green900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
          margin: const EdgeInsets.all(16),
        ),
      );
      context.go(MintflowRoutes.login);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintflowColors.ink10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Change password', style: MintflowTextStyles.displaySmall),
            const SizedBox(height: 6),
            Text(
              'You’ll be signed out everywhere after updating.',
              style: MintflowTextStyles.bodySmall
                  .copyWith(color: MintflowColors.ink60),
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _currentCtrl,
              label: 'Current password',
              obscure: _obscure,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _newCtrl,
              label: 'New password',
              obscure: _obscure,
            ),
            const SizedBox(height: 12),
            _PasswordField(
              controller: _confirmCtrl,
              label: 'Confirm new password',
              obscure: _obscure,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              child: Text(_obscure ? 'Show passwords' : 'Hide passwords'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: MintflowTextStyles.bodySmall
                      .copyWith(color: MintflowColors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintflowColors.green400,
                  foregroundColor: MintflowColors.green900,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: MintflowRadius.lg_,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Update password',
                        style: MintflowTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: MintflowColors.green900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: MintflowColors.cream,
        border: OutlineInputBorder(
          borderRadius: MintflowRadius.lg_,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: MintflowRadius.xl_,
        border: Border.all(color: MintflowColors.ink10),
      ),
      child: Column(children: children),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: MintflowColors.ink10);
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.subtitle,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: MintflowRadius.xl_,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: MintflowRadius.md_,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintflowTextStyles.labelMedium.copyWith(
                      color: labelColor ?? MintflowColors.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MintflowTextStyles.overline
                          .copyWith(color: MintflowColors.ink60),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: MintflowColors.ink30, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: MintflowRadius.md_,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintflowTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: MintflowTextStyles.overline
                      .copyWith(color: MintflowColors.ink60),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintflowColors.green400,
          ),
        ],
      ),
    );
  }
}
