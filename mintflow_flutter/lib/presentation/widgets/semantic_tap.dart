import 'package:flutter/material.dart';

/// Tappable surface with an explicit screen-reader name and button role.
///
/// When [minTapTarget] is true (default), the hit box is at least 48×48 dp
/// (Material / Android comfort; covers iOS 44 pt).
class SemanticTap extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool selected;
  final bool excludeSemantics;
  final bool minTapTarget;
  final HitTestBehavior behavior;

  const SemanticTap({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.excludeSemantics = false,
    this.minTapTarget = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    Widget tapChild = child;
    if (minTapTarget) {
      tapChild = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: child,
      );
    }
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: excludeSemantics,
      child: GestureDetector(
        onTap: onTap,
        behavior: behavior,
        child: tapChild,
      ),
    );
  }
}
