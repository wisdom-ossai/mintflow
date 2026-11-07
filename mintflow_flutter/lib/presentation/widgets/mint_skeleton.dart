import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion.dart';

/// Layout-stable shimmer placeholder. Honors Reduce Motion.
class MintSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const MintSkeleton({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<MintSkeleton> createState() => _MintSkeletonState();
}

class _MintSkeletonState extends State<MintSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MintMotion.reduce(context)) {
      _controller.stop();
      _controller.value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = MintflowColors.softFill(context);
    final highlight = MintflowColors.hairline(context);

    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.width ?? double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(base, highlight, _controller.value),
              borderRadius: widget.borderRadius ?? MintflowRadius.md_,
            ),
          );
        },
      ),
    );
  }
}

/// Home feed placeholder matching ring-first layout.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: MintflowColors.green900,
            alignment: Alignment.center,
            child: const MintSkeleton(
              height: 160,
              width: 160,
              borderRadius: BorderRadius.all(Radius.circular(80)),
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MintflowSpacing.xl),
            decoration: BoxDecoration(
              color: MintflowColors.page(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick actions row
                Row(
                  children: [
                    Expanded(child: MintSkeleton(height: 72)),
                    SizedBox(width: MintflowSpacing.sm),
                    Expanded(child: MintSkeleton(height: 72)),
                    SizedBox(width: MintflowSpacing.sm),
                    Expanded(child: MintSkeleton(height: 72)),
                    SizedBox(width: MintflowSpacing.sm),
                    Expanded(child: MintSkeleton(height: 72)),
                  ],
                ),
                SizedBox(height: MintflowSpacing.lg),
                // Month pulse
                MintSkeleton(height: 64),
                SizedBox(height: MintflowSpacing.lg),
                // Coaching teaser
                MintSkeleton(height: 88),
                SizedBox(height: MintflowSpacing.lg),
                MintSkeleton(height: 20, width: 120),
                SizedBox(height: MintflowSpacing.md),
                MintSkeleton(height: 56),
                SizedBox(height: MintflowSpacing.sm),
                MintSkeleton(height: 56),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
