import 'package:flutter/material.dart';

/// Material window-size style breakpoints for adaptive shell layout.
class MintBreakpoints {
  MintBreakpoints._();

  /// Compact → medium boundary (phone / narrow split view).
  static const double medium = 600;

  /// Medium → expanded (tablet / desktop): prefer rail over bottom bar.
  static const double expanded = 840;

  /// Readable measure for auth / single-column forms.
  static const double formMax = 480;

  /// Content column before multi-pane or multi-card layouts take over.
  static const double contentMax = 960;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isExpanded(BuildContext context) =>
      widthOf(context) >= expanded;

  static bool isMediumOrUp(BuildContext context) =>
      widthOf(context) >= medium;

  /// Horizontal inset: tighter on phone, roomier on medium+.
  static double pageGutter(BuildContext context) =>
      isMediumOrUp(context) ? 32 : 20;
}

/// Centers [child] and caps its width so tablet/desktop don't stretch phone UI.
///
/// Uses [Align.heightFactor] / [Align.widthFactor] of 1 so this never expands
/// to fill a loose parent (e.g. Scaffold `bottomNavigationBar`) — that used to
/// pin sticky CTAs under the status bar and collapse the scroll body.
class MintAdaptiveWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const MintAdaptiveWidth({
    super.key,
    required this.child,
    this.maxWidth = MintBreakpoints.formMax,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      // Shrink-wrap height so loose parents (Scaffold bottom bars) don't expand.
      // Leave widthFactor null so we still fill and center horizontally.
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
