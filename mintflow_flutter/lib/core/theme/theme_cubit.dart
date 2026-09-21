import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/local_cache.dart';

/// Persisted appearance: system / light / dark. Applies on Android and iOS
/// through [MaterialApp.themeMode].
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(_readStored());

  static ThemeMode _readStored() {
    switch (MintflowCache.getPref(CacheKeys.themeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    emit(mode);
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await MintflowCache.setPref(CacheKeys.themeMode, value);
  }
}
