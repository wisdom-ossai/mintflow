import 'package:flowra_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class Label extends StatelessWidget {
  // export Label
  final String text;
  const Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: FlowraTextStyles.overline.copyWith(color: FlowraColors.ink60),
      );
}
