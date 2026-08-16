import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../widgets/label.dart';
import '../../widgets/error_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resetPassword = FlowraRoutes.resetPassword;
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
        redirectTo: 'flowra:/$resetPassword',
      );
      if (mounted) {
        context.push(
          FlowraRoutes.checkEmail,
          extra: _emailCtrl.text.trim(),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      body: Column(children: [
        // ── Dark top panel ──────────────────────────────────────────────────
        _ForgotTopPanel(),

        // ── Form ────────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Explanation
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: FlowraColors.creamDark,
                      borderRadius: FlowraRadius.lg_,
                      border: Border.all(color: FlowraColors.ink10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: FlowraColors.ink60),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter the email address you signed up with. '
                            "We'll send you a secure link to reset your password.",
                            style: FlowraTextStyles.bodySmall.copyWith(
                              color: FlowraColors.ink60,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    ErrorBanner(message: _error!),
                    const SizedBox(height: 4),
                  ],

                  Label('Email address'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    onFieldSubmitted: (_) => _sendReset(),
                    decoration: const InputDecoration(
                      hintText: 'you@email.com',
                      prefixIcon: Icon(Icons.email_outlined,
                          size: 18, color: Color(0x990F1F14)),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty || !v.contains('@'))
                            ? 'Enter a valid email address'
                            : null,
                  ),
                  const SizedBox(height: 28),

                  // Send reset link button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendReset,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Send reset link'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Back to sign in
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(FlowraRoutes.login),
                      icon: const Icon(Icons.arrow_back,
                          size: 16, color: FlowraColors.green500),
                      label: Text('Back to sign in',
                          style: FlowraTextStyles.labelMedium
                              .copyWith(color: FlowraColors.green500)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Top panel for forgot password ─────────────────────────────────────────────

class _ForgotTopPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: FlowraColors.green900,
      child: Stack(children: [
        // Decorative circles
        Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlowraColors.green400.withOpacity(0.1),
              ),
            )),
        Positioned(
            bottom: -20,
            left: 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlowraColors.gold400.withOpacity(0.08),
              ),
            )),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: FlowraRadius.sm_,
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(height: 20),

                // Lock icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: FlowraColors.green400.withOpacity(0.2),
                    borderRadius: FlowraRadius.lg_,
                    border: Border.all(
                        color: FlowraColors.green400.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.lock_reset_outlined,
                      color: FlowraColors.green400, size: 26),
                ),
                const SizedBox(height: 14),

                Text('Forgot\nyour password?',
                    style: FlowraTextStyles.displaySmall.copyWith(
                        color: FlowraColors.cream,
                        fontStyle: FontStyle.italic,
                        height: 1.2)),
                const SizedBox(height: 6),
                Text('No worries — happens to the best of us.',
                    style: FlowraTextStyles.bodySmall.copyWith(
                        color: FlowraColors.cream.withOpacity(0.5),
                        fontWeight: FontWeight.w300)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
