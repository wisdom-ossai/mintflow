import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../widgets/label.dart';
import '../../widgets/mini_logo_painter.dart';
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
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        data: {'full_name': _nameCtrl.text.trim()},
      );
      AuthGate.setOnboardingComplete(false);
      if (mounted) context.go(FlowraRoutes.onboarding);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: FlowraColors.green400,
                        borderRadius: BorderRadius.circular(13)),
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

                // 7-day trial badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: FlowraColors.green50,
                    borderRadius: FlowraRadius.md_,
                    border: Border.all(color: FlowraColors.green100),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: FlowraColors.green400),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      '7-day free trial — all Pro features unlocked. No card needed.',
                      style: FlowraTextStyles.bodySmall
                          .copyWith(color: FlowraColors.green600),
                    )),
                  ]),
                ),
                const SizedBox(height: 24),

                Text('Create your account',
                    style: FlowraTextStyles.displayMedium),
                const SizedBox(height: 6),
                Text('Start tracking in under 2 minutes',
                    style: FlowraTextStyles.bodyMedium
                        .copyWith(color: FlowraColors.ink60)),
                const SizedBox(height: 28),

                if (_error != null) ErrorBanner(message: _error!),

                Label('Full name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Alex Johnson'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 16),

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

                Label('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signup(),
                  decoration: InputDecoration(
                    hintText: 'Min. 8 characters',
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
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Password must be at least 8 characters'
                      : null,
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
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Create account — free'),
                  ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: () => context.go(FlowraRoutes.login),
                    child: RichText(
                      text: TextSpan(
                        style: FlowraTextStyles.bodySmall
                            .copyWith(color: FlowraColors.ink60),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                color: FlowraColors.green500,
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'By signing up you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: FlowraTextStyles.overline
                        .copyWith(color: FlowraColors.ink30),
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
