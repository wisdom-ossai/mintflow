import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_theme.dart';
import 'theme_cubit.dart';

/// Light / Dark / System segmented control. Used on Profile and Settings.
class AppearanceControl extends StatelessWidget {
  const AppearanceControl({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        final options = const [
          (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
          (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
          (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
        ];
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: MintflowColors.softFill(context),
            borderRadius: MintflowRadius.md_,
          ),
          child: Row(
            children: [
              for (final opt in options)
                Expanded(
                  child: _Segment(
                    selected: mode == opt.$1,
                    icon: opt.$2,
                    label: opt.$3,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<ThemeCubit>().setMode(opt.$1);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Segment({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? MintflowColors.card(context) : Colors.transparent,
          borderRadius: MintflowRadius.sm_,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? MintflowColors.green500
                  : MintflowColors.textTertiary(context),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: MintflowTextStyles.overline.copyWith(
                color: selected
                    ? MintflowColors.textPrimary(context)
                    : MintflowColors.textSecondary(context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
