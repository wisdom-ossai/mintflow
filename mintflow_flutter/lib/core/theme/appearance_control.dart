import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'theme_cubit.dart';

/// Light / Dark / System segmented control. Used on Profile and Settings.
class AppearanceControl extends StatelessWidget {
  const AppearanceControl({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        return SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              context.read<ThemeCubit>().setMode(selection.first);
            },
            showSelectedIcon: false,
          ),
        );
      },
    );
  }
}
