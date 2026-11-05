import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../core/utils/revenuecat.dart';
import '../../../core/utils/social_auth.dart';
import '../../../data/datasources/service_locator.dart';
import '../../../core/theme/mint_inputs.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/error_banner.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ServiceLocator.instance.api.signup(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
      );
      await identifyRevenueCat(result.user.id);
      AuthGate.setOnboardingComplete(false);
      if (mounted) context.go(MintflowRoutes.onboarding);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
    }
  }

  Future<void> _afterSocial(String userId) async {
    await identifyRevenueCat(userId);
    AuthGate.setOnboardingComplete(false);
    if (mounted) context.go(MintflowRoutes.onboarding);
  }

  Future<void> _googleSignup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final idToken = await googleIdToken();
      final result =
          await ServiceLocator.instance.api.google(idToken: idToken);
      if (!mounted) return;
      await _afterSocial(result.user.id);
    } on GoogleSignInCanceled {
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
    }
  }

  Future<void> _appleSignup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final apple = await appleIdentity();
      final result = await ServiceLocator.instance.api.apple(
        identityToken: apple.identityToken,
        email: apple.email,
        fullName: apple.fullName,
      );
      if (!mounted) return;
      await _afterSocial(result.user.id);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
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
      body: SafeArea(
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
                  const SizedBox(height: 24),
                  BrandLogo(
                    size: 40,
                    showWordmark: true,
                    wordmarkColor: MintflowColors.textPrimary(context),
                  ),
                  const SizedBox(height: 40),

                  // 7-day trial badge
                  Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: MintflowColors.mintWash(context),
                    borderRadius: MintflowRadius.md_,
                    border: Border.all(color: MintflowColors.green100),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: MintflowColors.green400),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      '7-day free trial — all Pro features unlocked. No card needed.',
                      style: MintflowTextStyles.bodySmall
                          .copyWith(color: MintflowColors.green600),
                    )),
                  ]),
                ),
                const SizedBox(height: 24),

                Text('Create your account',
                    style: MintflowTextStyles.displayMedium.copyWith(
                        color: MintflowColors.textPrimary(context))),
                const SizedBox(height: 6),
                Text('Start tracking in under 2 minutes',
                    style: MintflowTextStyles.bodyMedium
                        .copyWith(color: MintflowColors.textSecondary(context))),
                const SizedBox(height: 28),

                if (_error != null) ErrorBanner(message: _error!),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: mintInputDecoration(
                    context,
                    label: 'Full name',
                    hint: 'Alex Johnson',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: mintInputDecoration(
                    context,
                    label: 'Email address',
                    hint: 'you@email.com',
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email address'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    // Re-validate confirm field when password changes.
                    if (_confirmCtrl.text.isNotEmpty) {
                      _formKey.currentState?.validate();
                    }
                  },
                  decoration: mintInputDecoration(
                    context,
                    label: 'Password',
                    hint: 'Min. 8 characters',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: MintflowColors.textSecondary(context),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Password must be at least 8 characters'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signup(),
                  decoration: mintInputDecoration(
                    context,
                    label: 'Confirm password',
                    hint: 'Re-enter your password',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Show password'
                          : 'Hide password',
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: MintflowColors.textSecondary(context),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (v != _passwordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: MintflowColors.green900,
                                strokeWidth: 2))
                        : const Text('Create account — free'),
                  ),
                ),
                const SizedBox(height: 24),

                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: MintflowTextStyles.labelSmall.copyWith(
                            color: MintflowColors.textSecondary(context))),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),

                Row(
                  children: [
                    if (isAppleSignInPlatform) ...[
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _appleSignup,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: MintflowColors.cream,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.apple, size: 20),
                            label: const Text('Apple'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _googleSignup,
                          icon: const _SignupGoogleIcon(),
                          label: const Text('Google'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: () => context.go(MintflowRoutes.login),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: MintflowTextStyles.bodySmall.copyWith(
                            color: MintflowColors.textSecondary(context)),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: MintflowColors.green600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      semanticsLabel: 'Already have an account? Sign in',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'By signing up you agree to our Terms & Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: MintflowTextStyles.overline.copyWith(
                          color: MintflowColors.textSecondary(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupGoogleIcon extends StatelessWidget {
  const _SignupGoogleIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: CustomPaint(painter: _SignupGooglePainter()),
      );
}

class _SignupGooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        (i * 90 - 45) * 3.14159 / 180,
        90 * 3.14159 / 180,
        true,
        Paint()..color = colors[i],
      );
    }
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_) => false;
}
