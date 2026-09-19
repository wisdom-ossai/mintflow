import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../core/utils/revenuecat.dart';
import '../../../data/datasources/service_locator.dart';
import '../../cubits/cubits.dart';
import '../../widgets/label.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/error_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterAuth(String userId) async {
    await identifyRevenueCat(userId);
    if (!mounted) return;
    try {
      await context.read<UserCubit>().load(forceRefresh: true);
      final state = context.read<UserCubit>().state;
      if (state is UserLoaded) {
        AuthGate.setOnboardingComplete(state.user.hasCompletedOnboarding);
        context.go(state.user.hasCompletedOnboarding
            ? MintflowRoutes.dashboard
            : MintflowRoutes.onboarding);
        return;
      }
    } catch (_) {}
    if (mounted) context.go(MintflowRoutes.dashboard);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ServiceLocator.instance.api.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      await _afterAuth(result.user.id);
    } catch (e) {
      setState(() {
        _error = friendlyAuthError(e);
        _loading = false;
      });
    }
  }

  Future<void> _googleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final serverClientId = (dotenv.env['GOOGLE_CLIENT_ID'] ?? '').trim();
      final iosClientId = (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '').trim();
      final googleSignIn = GoogleSignIn(
        clientId: iosClientId.isEmpty ? null : iosClientId,
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
        scopes: const ['email', 'profile'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google Sign-In did not return an ID token. '
          'Set GOOGLE_CLIENT_ID to the Web OAuth client ID in .env.',
        );
      }
      final result =
          await ServiceLocator.instance.api.google(idToken: idToken);
      if (!mounted) return;
      await _afterAuth(result.user.id);
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
      backgroundColor: MintflowColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const BrandLogo(
                  size: 40,
                  showWordmark: true,
                  wordmarkColor: MintflowColors.green900,
                ),
                const SizedBox(height: 40),
                Text('Welcome back', style: MintflowTextStyles.displayMedium),
                const SizedBox(height: 6),
                Text('Sign in to your account',
                    style: MintflowTextStyles.bodyMedium
                        .copyWith(color: MintflowColors.ink60)),
                const SizedBox(height: 32),

                // Error banner
                if (_error != null) ErrorBanner(message: _error!),

                // Email
                Label('Email address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'you@email.com'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),

                // Password
                Label('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: MintflowColors.ink60,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Password too short' : null,
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go(MintflowRoutes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),

                // Sign in button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: MintflowTextStyles.labelSmall
                            .copyWith(color: MintflowColors.ink60)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),

                // Google
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _googleLogin,
                    icon: const _GoogleIcon(),
                    label: const Text('Continue with Google'),
                  ),
                ),
                const SizedBox(height: 32),

                // Sign up link
                Center(
                  child: GestureDetector(
                    onTap: () => context.go(MintflowRoutes.signup),
                    child: RichText(
                      text: TextSpan(
                        style: MintflowTextStyles.bodySmall
                            .copyWith(color: MintflowColors.ink60),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: MintflowColors.green500,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: CustomPaint(painter: _GooglePainter()),
      );
}

class _GooglePainter extends CustomPainter {
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
