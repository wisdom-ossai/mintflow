import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow Design System
// Brand: navy (#05122B) + mint (#2CE683) + white. Calm, modern, trustworthy.
// Token names kept for compatibility; values remapped to Mintflow palette.
// ─────────────────────────────────────────────────────────────────────────────

// ── Color palette ─────────────────────────────────────────────────────────────

class MintflowColors {
  MintflowColors._();

  // Brand navy / mint (legacy green* names map to Mintflow navy+mint)
  static const green900 = Color(0xFF05122B); // navy
  static const green600 = Color(0xFF1EA35D); // deep mint
  static const green500 = Color(0xFF24C974); // mid mint
  static const green400 = Color(0xFF2CE683); // primary mint
  static const green100 = Color(0xFFB8F5D4); // mint soft
  static const green50 = Color(0xFFE8FBF2); // mint wash

  // Accents (mapped to mint-adjacent neutrals — no gold in Mintflow brand)
  static const gold500 = Color(0xFF1EA35D);
  static const gold400 = Color(0xFF2CE683);
  static const gold300 = Color(0xFF6EF0A8);
  static const gold100 = Color(0xFFB8F5D4);
  static const gold50 = Color(0xFFE8FBF2);

  // Neutrals / surfaces
  static const cream = Color(0xFFF4F7FB); // cool off-white
  static const creamDark = Color(0xFFE8EDF5);
  static const ink = Color(0xFF05122B);
  static const ink60 = Color(0x9905122B);
  static const ink30 = Color(0x4D05122B);
  static const ink10 = Color(0x1A05122B);

  // Semantic
  static const red = Color(0xFFE05A40);
  static const redSoft = Color(0xFFFFF0EE);
  static const purple = Color(0xFF7B5CF0);
  static const purpleSoft = Color(0xFFF5F0FF);
  static const blue = Color(0xFF4A6CF7);
  static const blueSoft = Color(0xFFF0F4FF);

  // Dark mode variants
  static const darkSurface = Color(0xFF05122B);
  static const darkCard = Color(0xFF0A1A38);
  static const darkBorder = Color(0xFF1A2E4A);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextMuted = Color(0xFF8BA3C0);
  static const darkSoftFill = Color(0xFF0F2244);
  static const darkFaint = Color(0xFF5A7394);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) =>
      isDark(context) ? darkSurface : cream;

  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : Colors.white;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? darkText : ink;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextMuted : ink60;

  static Color textTertiary(BuildContext context) =>
      isDark(context) ? darkFaint : ink30;

  static Color stroke(BuildContext context) =>
      isDark(context) ? darkBorder : creamDark;

  static Color hairline(BuildContext context) =>
      isDark(context) ? darkBorder : ink10;

  static Color softFill(BuildContext context) =>
      isDark(context) ? darkSoftFill : creamDark;

  static Color mintWash(BuildContext context) =>
      isDark(context) ? green400.withOpacity(0.14) : green50;

  static Color goldWash(BuildContext context) =>
      isDark(context) ? gold400.withOpacity(0.14) : gold50;

  static Color blueWash(BuildContext context) =>
      isDark(context) ? blue.withOpacity(0.16) : blueSoft;

  static Color purpleWash(BuildContext context) =>
      isDark(context) ? purple.withOpacity(0.16) : purpleSoft;

  static Color redWash(BuildContext context) =>
      isDark(context) ? red.withOpacity(0.16) : redSoft;
}

// ── Typography ────────────────────────────────────────────────────────────────

class MintflowTextStyles {
  MintflowTextStyles._();

  static const String _poppins = 'Poppins';
  static const String _sans = 'DMSans';

  // Display — serif for headlines
  static const displayLarge = TextStyle(
    fontFamily: _poppins,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static const displayMedium = TextStyle(
    fontFamily: _poppins,
    fontSize: 26,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    height: 1.25,
  );
  static const displaySmall = TextStyle(
    fontFamily: _poppins,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.3,
  );
  static const displayItalic = TextStyle(
    fontFamily: _poppins,
    fontSize: 22,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    height: 1.3,
  );

  // Body — sans for UI
  static const bodyLarge = TextStyle(
    fontFamily: _sans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );
  static const bodySmall = TextStyle(
    fontFamily: _sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  // Labels
  static const labelLarge = TextStyle(
    fontFamily: _sans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );
  static const labelMedium = TextStyle(
    fontFamily: _sans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.02,
    height: 1.4,
  );
  static const labelSmall = TextStyle(
    fontFamily: _sans,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.06,
    height: 1.4,
  );
  static const overline = TextStyle(
    fontFamily: _sans,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.08,
    height: 1.4,
  );

  // Numeric / amounts
  static const amountLarge = TextStyle(
    fontFamily: _poppins,
    fontSize: 42,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    height: 1.0,
  );
  static const amountMedium = TextStyle(
    fontFamily: _poppins,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    height: 1.0,
  );
  static const amountSmall = TextStyle(
    fontFamily: _poppins,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.1,
  );
}

// ── Spacing ───────────────────────────────────────────────────────────────────

class MintflowSpacing {
  MintflowSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double section = 40;
}

// ── Border radius ─────────────────────────────────────────────────────────────

class MintflowRadius {
  MintflowRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;

  static final sm_ = BorderRadius.circular(sm);
  static final md_ = BorderRadius.circular(md);
  static final lg_ = BorderRadius.circular(lg);
  static final xl_ = BorderRadius.circular(xl);
  static final xxl_ = BorderRadius.circular(xxl);
  static final pill_ = BorderRadius.circular(pill);
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class MintflowTheme {
  MintflowTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: MintflowColors.cream,
        primaryColor: MintflowColors.green400,
        colorScheme: ColorScheme.light(
          primary: MintflowColors.green400,
          onPrimary: Colors.white,
          primaryContainer: MintflowColors.green50,
          secondary: MintflowColors.gold400,
          onSecondary: MintflowColors.ink,
          surface: Colors.white,
          onSurface: MintflowColors.ink,
          error: MintflowColors.red,
          background: MintflowColors.cream,
          onBackground: MintflowColors.ink,
          outline: MintflowColors.ink10,
        ),
        fontFamily: 'DMSans',
        textTheme: TextTheme(
          displayLarge:
              MintflowTextStyles.displayLarge.copyWith(color: MintflowColors.ink),
          displayMedium:
              MintflowTextStyles.displayMedium.copyWith(color: MintflowColors.ink),
          displaySmall:
              MintflowTextStyles.displaySmall.copyWith(color: MintflowColors.ink),
          bodyLarge:
              MintflowTextStyles.bodyLarge.copyWith(color: MintflowColors.ink),
          bodyMedium:
              MintflowTextStyles.bodyMedium.copyWith(color: MintflowColors.ink),
          bodySmall:
              MintflowTextStyles.bodySmall.copyWith(color: MintflowColors.ink60),
          labelLarge:
              MintflowTextStyles.labelLarge.copyWith(color: MintflowColors.ink),
          labelMedium:
              MintflowTextStyles.labelMedium.copyWith(color: MintflowColors.ink60),
          labelSmall:
              MintflowTextStyles.labelSmall.copyWith(color: MintflowColors.ink60),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: MintflowColors.green900,
          foregroundColor: MintflowColors.cream,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: MintflowTextStyles.displaySmall.copyWith(
            color: MintflowColors.cream,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: MintflowColors.green500,
          unselectedItemColor: MintflowColors.ink30,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: MintflowTextStyles.overline,
          unselectedLabelStyle: MintflowTextStyles.overline,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: MintflowRadius.lg_,
            side: BorderSide(color: MintflowColors.ink10, width: 1),
          ),
          margin: const EdgeInsets.only(bottom: MintflowSpacing.md),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: MintflowColors.green400,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: MintflowSpacing.xxl,
              vertical: MintflowSpacing.lg,
            ),
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.lg_),
            textStyle: MintflowTextStyles.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: MintflowColors.green400,
            side: const BorderSide(color: MintflowColors.green400),
            padding: const EdgeInsets.symmetric(
              horizontal: MintflowSpacing.xxl,
              vertical: MintflowSpacing.lg,
            ),
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.lg_),
            textStyle: MintflowTextStyles.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: MintflowColors.green500,
            textStyle: MintflowTextStyles.labelMedium,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: MintflowSpacing.lg,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide: BorderSide(color: MintflowColors.ink10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide: BorderSide(color: MintflowColors.ink10, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide:
                const BorderSide(color: MintflowColors.green400, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide: const BorderSide(color: MintflowColors.red, width: 1.5),
          ),
          labelStyle:
              MintflowTextStyles.labelMedium.copyWith(color: MintflowColors.ink60),
          hintStyle:
              MintflowTextStyles.bodyMedium.copyWith(color: MintflowColors.ink30),
        ),
        dividerTheme: DividerThemeData(
          color: MintflowColors.ink10,
          thickness: 1,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: MintflowColors.creamDark,
          selectedColor: MintflowColors.green900,
          labelStyle: MintflowTextStyles.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: MintflowRadius.pill_,
            side: BorderSide(color: MintflowColors.ink10),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MintflowColors.darkSurface,
        primaryColor: MintflowColors.green400,
        colorScheme: ColorScheme.dark(
          primary: MintflowColors.green400,
          onPrimary: MintflowColors.ink,
          primaryContainer: MintflowColors.darkSoftFill,
          secondary: MintflowColors.gold400,
          onSecondary: MintflowColors.ink,
          surface: MintflowColors.darkCard,
          onSurface: MintflowColors.darkText,
          error: MintflowColors.red,
          background: MintflowColors.darkSurface,
          onBackground: MintflowColors.darkText,
          outline: MintflowColors.darkBorder,
        ),
        fontFamily: 'DMSans',
        textTheme: TextTheme(
          displayLarge: MintflowTextStyles.displayLarge
              .copyWith(color: MintflowColors.darkText),
          displayMedium: MintflowTextStyles.displayMedium
              .copyWith(color: MintflowColors.darkText),
          displaySmall: MintflowTextStyles.displaySmall
              .copyWith(color: MintflowColors.darkText),
          bodyLarge: MintflowTextStyles.bodyLarge
              .copyWith(color: MintflowColors.darkText),
          bodyMedium: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.darkText),
          bodySmall: MintflowTextStyles.bodySmall
              .copyWith(color: MintflowColors.darkTextMuted),
          labelLarge: MintflowTextStyles.labelLarge
              .copyWith(color: MintflowColors.darkText),
          labelMedium: MintflowTextStyles.labelMedium
              .copyWith(color: MintflowColors.darkTextMuted),
          labelSmall: MintflowTextStyles.labelSmall
              .copyWith(color: MintflowColors.darkTextMuted),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: MintflowColors.green900,
          foregroundColor: MintflowColors.cream,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: MintflowTextStyles.displaySmall.copyWith(
            color: MintflowColors.cream,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: MintflowColors.darkCard,
          selectedItemColor: MintflowColors.green400,
          unselectedItemColor: MintflowColors.darkTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: MintflowTextStyles.overline,
          unselectedLabelStyle: MintflowTextStyles.overline,
        ),
        cardTheme: CardThemeData(
          color: MintflowColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: MintflowRadius.lg_,
            side: BorderSide(color: MintflowColors.darkBorder, width: 1),
          ),
          margin: const EdgeInsets.only(bottom: MintflowSpacing.md),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: MintflowColors.green400,
            foregroundColor: MintflowColors.ink,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: MintflowSpacing.xxl,
              vertical: MintflowSpacing.lg,
            ),
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.lg_),
            textStyle: MintflowTextStyles.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: MintflowColors.green400,
            side: const BorderSide(color: MintflowColors.green400),
            padding: const EdgeInsets.symmetric(
              horizontal: MintflowSpacing.xxl,
              vertical: MintflowSpacing.lg,
            ),
            shape: RoundedRectangleBorder(borderRadius: MintflowRadius.lg_),
            textStyle: MintflowTextStyles.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: MintflowColors.green400,
            textStyle: MintflowTextStyles.labelMedium,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: MintflowColors.darkCard,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: MintflowSpacing.lg,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide: BorderSide(color: MintflowColors.darkBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide: BorderSide(color: MintflowColors.darkBorder, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide:
                const BorderSide(color: MintflowColors.green400, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: MintflowRadius.lg_,
            borderSide: const BorderSide(color: MintflowColors.red, width: 1.5),
          ),
          labelStyle: MintflowTextStyles.labelMedium
              .copyWith(color: MintflowColors.darkTextMuted),
          hintStyle: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.darkFaint),
        ),
        dividerTheme: const DividerThemeData(
          color: MintflowColors.darkBorder,
          thickness: 1,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: MintflowColors.darkSoftFill,
          selectedColor: MintflowColors.green400,
          labelStyle: MintflowTextStyles.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: MintflowRadius.pill_,
            side: BorderSide(color: MintflowColors.darkBorder),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: MintflowColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: MintflowRadius.xl_),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: MintflowColors.darkSurface,
          modalBackgroundColor: MintflowColors.darkSurface,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: MintflowColors.darkCard,
          contentTextStyle: MintflowTextStyles.bodyMedium
              .copyWith(color: MintflowColors.darkText),
          shape: RoundedRectangleBorder(borderRadius: MintflowRadius.md_),
          behavior: SnackBarBehavior.floating,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? MintflowColors.green400
                : MintflowColors.darkBorder;
          }),
        ),
      );
}
