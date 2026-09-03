import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_errors.dart';
import '../../../data/datasources/service_locator.dart';
import '../../widgets/label.dart';
import '../../widgets/error_banner.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _success = false;
  String? _error;

  // Password strength
  int get _strength {
    final p = _passwordCtrl.text;
    int score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) score++;
    return score;
  }

  String get _strengthLabel {
    if (_strength <= 1) return 'Weak';
    if (_strength <= 3) return 'Fair';
    if (_strength == 4) return 'Good';
    return 'Strong';
  }

  Color get _strengthColor {
    if (_strength <= 1) return FlowraColors.red;
    if (_strength <= 3) return FlowraColors.gold500;
    return FlowraColors.green400;
  }

  String? get _resetToken {
    final fromWidget = widget.token?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    final uri = GoRouterState.of(context).uri;
    final q = uri.queryParameters['token']?.trim();
    if (q != null && q.isNotEmpty) return q;
    return null;
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final token = _resetToken;
    if (token == null) {
      setState(() {
        _error =
            'This reset link is missing a token. Open the link from your email again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ServiceLocator.instance.api.resetPassword(
        token: token,
        password: _passwordCtrl.text,
      );
      setState(() {
        _success = true;
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
        _ResetTopPanel(),
        Expanded(
          child: _success
              ? _SuccessState(onSignIn: () => context.go(FlowraRoutes.login))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          ErrorBanner(message: _error!),
                          const SizedBox(height: 4),
                        ],

                        Label('New password'),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure1,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Min. 8 characters',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure1
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: FlowraColors.ink60,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure1 = !_obscure1),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'Password must be at least 8 characters'
                              : null,
                        ),

                        // Strength meter
                        if (_passwordCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: FlowraRadius.pill_,
                                child: LinearProgressIndicator(
                                  value: _strength / 5,
                                  minHeight: 4,
                                  backgroundColor: FlowraColors.creamDark,
                                  color: _strengthColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(_strengthLabel,
                                style: FlowraTextStyles.labelSmall.copyWith(
                                    color: _strengthColor,
                                    fontWeight: FontWeight.w500)),
                          ]),
                          const SizedBox(height: 6),
                          _PasswordRules(password: _passwordCtrl.text),
                        ],
                        const SizedBox(height: 16),

                        Label('Confirm new password'),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure2,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _resetPassword(),
                          decoration: InputDecoration(
                            hintText: 'Repeat your new password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure2
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: FlowraColors.ink60,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure2 = !_obscure2),
                            ),
                          ),
                          validator: (v) => v != _passwordCtrl.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _resetPassword,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Set new password'),
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

class _ResetTopPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: FlowraColors.green900,
      child: Stack(children: [
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
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: FlowraColors.green400,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.eco_outlined,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('Mintflow',
                      style: FlowraTextStyles.displaySmall.copyWith(
                        color: FlowraColors.cream,
                        fontFamily: 'DMSerifDisplay',
                        fontSize: 20,
                      )),
                ]),
                const SizedBox(height: 20),

                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: FlowraColors.green400.withOpacity(0.2),
                    borderRadius: FlowraRadius.lg_,
                    border: Border.all(
                        color: FlowraColors.green400.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.key_outlined,
                      color: FlowraColors.green400, size: 24),
                ),
                const SizedBox(height: 14),

                Text('Set a new\npassword',
                    style: FlowraTextStyles.displaySmall.copyWith(
                        color: FlowraColors.cream,
                        fontStyle: FontStyle.italic,
                        height: 1.2)),
                const SizedBox(height: 6),
                Text('Choose something strong and memorable.',
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

// Password rule checklist shown below the field
class _PasswordRules extends StatelessWidget {
  final String password;
  const _PasswordRules({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = [
      _Rule('At least 8 characters', password.length >= 8),
      _Rule('One uppercase letter', password.contains(RegExp(r'[A-Z]'))),
      _Rule('One number', password.contains(RegExp(r'[0-9]'))),
      _Rule('One special character (!@#\$...)',
          password.contains(RegExp(r'[!@#\$%^&*]'))),
    ];

    return Column(
      children: rules
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Icon(
                    r.met ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 13,
                    color: r.met ? FlowraColors.green400 : FlowraColors.ink30,
                  ),
                  const SizedBox(width: 6),
                  Text(r.label,
                      style: FlowraTextStyles.overline.copyWith(
                        color:
                            r.met ? FlowraColors.green600 : FlowraColors.ink60,
                        fontWeight: r.met ? FontWeight.w500 : FontWeight.w400,
                        fontSize: 11,
                      )),
                ]),
              ))
          .toList(),
    );
  }
}

class _Rule {
  final String label;
  final bool met;
  const _Rule(this.label, this.met);
}

// Success state after password reset
class _SuccessState extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SuccessState({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: FlowraColors.green50,
              borderRadius: FlowraRadius.xl_,
              border: Border.all(color: FlowraColors.green100, width: 1.5),
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 46, color: FlowraColors.green500),
          ),
          const SizedBox(height: 24),
          Text('Password updated!',
              style: FlowraTextStyles.displaySmall
                  .copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          Text(
            'Your password has been changed successfully. '
            'Sign in with your new password.',
            textAlign: TextAlign.center,
            style: FlowraTextStyles.bodyMedium
                .copyWith(color: FlowraColors.ink60, height: 1.6),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
