import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../data/datasources/service_locator.dart';
import '../../../core/theme/mint_inputs.dart';
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
      await ServiceLocator.instance.api.forgotPassword(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        context.push(
          MintflowRoutes.checkEmail,
          extra: _emailCtrl.text.trim(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.page(context),
      body: Column(children: [
        // ── Dark top panel ──────────────────────────────────────────────────
        _ForgotTopPanel(),

        // ── Form ────────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              MintBreakpoints.pageGutter(context),
              24,
              MintBreakpoints.pageGutter(context),
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: MintAdaptiveWidth(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Explanation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MintflowColors.softFill(context),
                      borderRadius: MintflowRadius.lg_,
                      border: Border.all(color: MintflowColors.hairline(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: MintflowColors.textSecondary(context)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Enter the email address you signed up with. '
                            "We'll send you a secure link to reset your password.",
                            style: MintflowTextStyles.bodySmall.copyWith(
                              color: MintflowColors.textSecondary(context),
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

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    onFieldSubmitted: (_) => _sendReset(),
                    decoration: mintInputDecoration(
                      context,
                      label: 'Email address',
                      hint: 'you@email.com',
                    ).copyWith(
                      prefixIcon: Icon(Icons.email_outlined,
                          size: 18,
                          color: MintflowColors.textSecondary(context)),
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
                                  color: MintflowColors.cream, strokeWidth: 2))
                          : const Text('Send reset link'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Back to sign in
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(MintflowRoutes.login),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      icon: const Icon(Icons.arrow_back,
                          size: 16, color: MintflowColors.green500),
                      label: Text('Back to sign in',
                          style: MintflowTextStyles.labelMedium
                              .copyWith(color: MintflowColors.green600)),
                    ),
                  ),
                ],
              ),
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
      color: MintflowColors.green900,
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
                color: MintflowColors.green400.withValues(alpha: 0.1),
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
                color: MintflowColors.gold400.withValues(alpha: 0.08),
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
                Semantics(
                  button: true,
                  label: 'Back',
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: MintflowColors.brandOverlay(context, 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: MintflowRadius.sm_,
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_back,
                        color: MintflowColors.cream, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                // Lock icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: MintflowColors.green400.withValues(alpha: 0.2),
                    borderRadius: MintflowRadius.lg_,
                    border: Border.all(
                        color: MintflowColors.green400.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.lock_reset_outlined,
                      color: MintflowColors.green400, size: 26),
                ),
                const SizedBox(height: 14),

                Text('Forgot\nyour password?',
                    style: MintflowTextStyles.displaySmall.copyWith(
                        color: MintflowColors.cream,
                        fontStyle: FontStyle.italic,
                        height: 1.2)),
                const SizedBox(height: 6),
                Text('We’ll email you a secure reset link.',
                    style: MintflowTextStyles.bodySmall.copyWith(
                        color: MintflowColors.onBrandMuted(context, 0.5),
                        fontWeight: FontWeight.w300)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
