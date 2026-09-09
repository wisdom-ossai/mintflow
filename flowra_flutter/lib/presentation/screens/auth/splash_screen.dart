import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/revenuecat.dart';
import '../../../data/datasources/service_locator.dart';
import '../../cubits/cubits.dart';
import '../../widgets/brand_logo.dart';

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

    final hasTokens = await ServiceLocator.instance.tokens.hasTokens();
    if (!hasTokens) {
      AuthGate.setAuthenticated(false);
      context.go(MintflowRoutes.login);
      return;
    }

    AuthGate.setAuthenticated(true);

    try {
      await context.read<UserCubit>().load(forceRefresh: true);
      if (!mounted) return;
      final state = context.read<UserCubit>().state;
      if (state is UserLoaded) {
        await identifyRevenueCat(state.user.id);
        final complete = state.user.hasCompletedOnboarding;
        AuthGate.setOnboardingComplete(complete);
        context.go(
            complete ? MintflowRoutes.dashboard : MintflowRoutes.onboarding);
        return;
      }
    } catch (_) {}

    AuthGate.setOnboardingComplete(true);
    if (mounted) context.go(MintflowRoutes.dashboard);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintflowColors.green900,
      body: Stack(children: [
        Positioned(top: -80, left: -60, child: _Ring(size: 420, opacity: 0.06)),
        Positioned(top: 60, left: 20, child: _Ring(size: 280, opacity: 0.04)),
        Positioned(
            bottom: 80,
            right: 20,
            child:
                _Ring(size: 160, opacity: 0.05, color: MintflowColors.green400)),
        Positioned(
            top: 110,
            right: 70,
            child: _Dot(color: MintflowColors.green400, size: 8, opacity: 0.6)),
        Positioned(
            bottom: 160,
            left: 50,
            child: _Dot(color: MintflowColors.green100, size: 5, opacity: 0.4)),
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const BrandLogo(size: 88),
                const SizedBox(height: 20),
                Text(
                  'Mintflow',
                  style: MintflowTextStyles.displayLarge.copyWith(
                    color: MintflowColors.cream,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
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
                    color: MintflowColors.green400,
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
      this.color = MintflowColors.green400});
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
