import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../cubits/cubits.dart';
import '../../widgets/label.dart';
import '../../widgets/mini_logo_painter.dart';
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      try {
        await context.read<UserCubit>().load(forceRefresh: true);
        final state = context.read<UserCubit>().state;
        if (state is UserLoaded) {
          AuthGate.setOnboardingComplete(state.user.hasCompletedOnboarding);
          context.go(state.user.hasCompletedOnboarding
              ? FlowraRoutes.dashboard
              : FlowraRoutes.onboarding);
          return;
        }
      } catch (_) {}
      context.go(FlowraRoutes.dashboard);
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

  Future<void> _googleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .signInWithOAuth(OAuthProvider.google, redirectTo: 'flowra://oauth');
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Logo
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FlowraColors.green400,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: CustomPaint(
                        size: const Size(40, 40), painter: MiniLogoPainter()),
                  ),
                  const SizedBox(width: 10),
                  Text('flowra',
                      style: FlowraTextStyles.displaySmall.copyWith(
                        fontFamily: 'DMSerifDisplay',
                        color: FlowraColors.green900,
                      )),
                ]),
                const SizedBox(height: 40),
                Text('Welcome back', style: FlowraTextStyles.displayMedium),
                const SizedBox(height: 6),
                Text('Sign in to your account',
                    style: FlowraTextStyles.bodyMedium
                        .copyWith(color: FlowraColors.ink60)),
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
                        color: FlowraColors.ink60,
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
                    onPressed: () => context.go(FlowraRoutes.forgotPassword),
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
                        style: FlowraTextStyles.labelSmall
                            .copyWith(color: FlowraColors.ink60)),
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
                    onTap: () => context.go(FlowraRoutes.signup),
                    child: RichText(
                      text: TextSpan(
                        style: FlowraTextStyles.bodySmall
                            .copyWith(color: FlowraColors.ink60),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: FlowraColors.green500,
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
  // export _GoogleIcon
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
