import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/service_locator.dart';

class CheckEmailScreen extends StatefulWidget {
  final String email;
  const CheckEmailScreen({super.key, required this.email});
  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen>
    with SingleTickerProviderStateMixin {
  bool _resending = false;
  bool _resent = false;
  int _countdown = 0;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _bounceAnim =
        CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);
    _bounceCtrl.forward();
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    setState(() {
      _resending = true;
      _resent = false;
    });
    try {
      await ServiceLocator.instance.api.forgotPassword(email: widget.email);
      setState(() {
        _resending = false;
        _resent = true;
        _countdown = 60;
      });
      _bounceCtrl
        ..reset()
        ..forward();
      _startCountdown();
    } catch (_) {
      setState(() => _resending = false);
    }
  }

  void _startCountdown() async {
    while (_countdown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdown--);
    }
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final name = parts[0];
    final domain = parts[1];
    final visible = name.length > 2 ? name.substring(0, 2) : name[0];
    return '$visible${'•' * (name.length - visible.length)}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Animated envelope icon
              ScaleTransition(
                scale: _bounceAnim,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: FlowraColors.green50,
                    borderRadius: FlowraRadius.xl_,
                    border:
                        Border.all(color: FlowraColors.green100, width: 1.5),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      size: 44, color: FlowraColors.green500),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text('Check your email',
                  style: FlowraTextStyles.displaySmall
                      .copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),

              // Description
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: FlowraTextStyles.bodyMedium
                      .copyWith(color: FlowraColors.ink60, height: 1.6),
                  children: [
                    const TextSpan(text: "We've sent a reset link to\n"),
                    TextSpan(
                      text: _maskedEmail,
                      style: TextStyle(
                        color: FlowraColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(
                      text: '\n\nClick the link in the email to '
                          'set a new password. It expires in 1 hour.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Steps card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: FlowraRadius.xl_,
                  border: Border.all(color: FlowraColors.ink10),
                ),
                child: Column(children: [
                  _Step(
                    number: '1',
                    text: 'Open your email app',
                    active: true,
                  ),
                  _StepDivider(),
                  _Step(
                    number: '2',
                    text: 'Find the email from Mintflow',
                    active: true,
                  ),
                  _StepDivider(),
                  _Step(
                    number: '3',
                    text: 'Tap "Reset my password"',
                    active: true,
                  ),
                  _StepDivider(),
                  _Step(
                    number: '4',
                    text: 'Choose a new password',
                    active: false,
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Resent success banner
              if (_resent)
                AnimatedOpacity(
                  opacity: _resent ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: FlowraColors.green50,
                      borderRadius: FlowraRadius.md_,
                      border: Border.all(color: FlowraColors.green100),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          color: FlowraColors.green500, size: 16),
                      const SizedBox(width: 8),
                      Text('Resent! Check your inbox again.',
                          style: FlowraTextStyles.bodySmall
                              .copyWith(color: FlowraColors.green600)),
                    ]),
                  ),
                ),

              const Spacer(),

              // Resend button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: (_resending || _countdown > 0) ? null : _resend,
                  child: _resending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: FlowraColors.green500))
                      : Text(
                          _countdown > 0
                              ? 'Resend in ${_countdown}s'
                              : "Didn't get it? Resend",
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Back to sign in
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.go(FlowraRoutes.login),
                  child: const Text('Back to sign in'),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Check your spam folder if you don\'t see it.',
                style: FlowraTextStyles.overline.copyWith(
                    color: FlowraColors.ink30, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number, text;
  final bool active;
  const _Step({required this.number, required this.text, required this.active});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: active ? FlowraColors.green400 : FlowraColors.creamDark,
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Text(number,
                    style: FlowraTextStyles.labelSmall.copyWith(
                        color: active ? Colors.white : FlowraColors.ink60,
                        fontWeight: FontWeight.w500))),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: FlowraTextStyles.bodySmall.copyWith(
                  color: active ? FlowraColors.ink : FlowraColors.ink60)),
        ]),
      );
}

class _StepDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 13),
        child: Container(width: 1.5, height: 12, color: FlowraColors.ink10),
      );
}
