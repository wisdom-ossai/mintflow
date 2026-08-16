import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../cubits/cubits.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go(FlowraRoutes.login);
      return;
    }

    try {
      await context.read<UserCubit>().load(forceRefresh: true);
      if (!mounted) return;
      final state = context.read<UserCubit>().state;
      if (state is UserLoaded) {
        final complete = state.user.hasCompletedOnboarding;
        AuthGate.setOnboardingComplete(complete);
        context.go(
            complete ? FlowraRoutes.dashboard : FlowraRoutes.onboarding);
        return;
      }
    } catch (_) {}

    // Soft-fail: allow dashboard; redirect may still send to onboarding later
    AuthGate.setOnboardingComplete(true);
    if (mounted) context.go(FlowraRoutes.dashboard);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowraColors.green900,
      body: Stack(children: [
        Positioned(top: -80, left: -60, child: _Ring(size: 420, opacity: 0.06)),
        Positioned(top: 60, left: 20, child: _Ring(size: 280, opacity: 0.04)),
        Positioned(
            bottom: 80,
            right: 20,
            child:
                _Ring(size: 160, opacity: 0.05, color: FlowraColors.gold400)),
        Positioned(
            top: 110,
            right: 70,
            child: _Dot(color: FlowraColors.gold400, size: 8, opacity: 0.6)),
        Positioned(
            bottom: 160,
            left: 50,
            child: _Dot(color: FlowraColors.green400, size: 5, opacity: 0.5)),
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: FlowraColors.green400,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: CustomPaint(painter: _LogoPainter()),
                ),
                const SizedBox(height: 20),
                Text(
                  'flowra',
                  style: FlowraTextStyles.displayLarge.copyWith(
                    color: FlowraColors.cream,
                    fontFamily: 'DMSerifDisplay',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'your money, flowing forward',
                  style: FlowraTextStyles.bodySmall.copyWith(
                    color: FlowraColors.cream.withOpacity(0.45),
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.04,
                  ),
                ),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 52,
          left: 0,
          right: 0,
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: SizedBox(
                width: 120,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    color: FlowraColors.green400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  final double size, opacity;
  final Color color;
  const _Ring(
      {required this.size,
      required this.opacity,
      this.color = FlowraColors.green400});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(opacity), width: 1),
        ),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size, opacity;
  const _Dot({required this.color, required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2, cy = size.height / 2;
    final path = Path()
      ..moveTo(cx, cy + 12)
      ..cubicTo(cx - 10, cy + 4, cx - 12, cy - 6, cx, cy - 12)
      ..cubicTo(cx + 12, cy - 6, cx + 10, cy + 4, cx, cy + 12);
    canvas.drawPath(
        path,
        paint
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        paint
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withOpacity(0.7));
    canvas.drawLine(
        Offset(cx, cy + 8),
        Offset(cx, cy - 8),
        paint
          ..color = Colors.white
          ..strokeWidth = 1.8);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx - 5, cy - 3), paint);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx + 5, cy - 3), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
