import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mintflow Design System
// Brand: navy (#05122B) + mint (#2CE683) + white. Calm, modern, trustworthy.
// Token names kept for compatibility; values remapped to Mintflow palette.
// ─────────────────────────────────────────────────────────────────────────────

// ── Color palette ─────────────────────────────────────────────────────────────

class FlowraColors {
  FlowraColors._();

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
}

// ── Typography ────────────────────────────────────────────────────────────────

class FlowraTextStyles {
  FlowraTextStyles._();

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

class FlowraSpacing {
  FlowraSpacing._();
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

class FlowraRadius {
  FlowraRadius._();
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

class FlowraTheme {
  FlowraTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: FlowraColors.cream,
        primaryColor: FlowraColors.green400,
        colorScheme: ColorScheme.light(
          primary: FlowraColors.green400,
          onPrimary: Colors.white,
          primaryContainer: FlowraColors.green50,
          secondary: FlowraColors.gold400,
          onSecondary: FlowraColors.ink,
          surface: Colors.white,
          onSurface: FlowraColors.ink,
          error: FlowraColors.red,
          background: FlowraColors.cream,
          onBackground: FlowraColors.ink,
          outline: FlowraColors.ink10,
        ),
        fontFamily: 'DMSans',
        textTheme: TextTheme(
          displayLarge:
              FlowraTextStyles.displayLarge.copyWith(color: FlowraColors.ink),
          displayMedium:
              FlowraTextStyles.displayMedium.copyWith(color: FlowraColors.ink),
          displaySmall:
              FlowraTextStyles.displaySmall.copyWith(color: FlowraColors.ink),
          bodyLarge:
              FlowraTextStyles.bodyLarge.copyWith(color: FlowraColors.ink),
          bodyMedium:
              FlowraTextStyles.bodyMedium.copyWith(color: FlowraColors.ink),
          bodySmall:
              FlowraTextStyles.bodySmall.copyWith(color: FlowraColors.ink60),
          labelLarge:
              FlowraTextStyles.labelLarge.copyWith(color: FlowraColors.ink),
          labelMedium:
              FlowraTextStyles.labelMedium.copyWith(color: FlowraColors.ink60),
          labelSmall:
              FlowraTextStyles.labelSmall.copyWith(color: FlowraColors.ink60),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: FlowraColors.green900,
          foregroundColor: FlowraColors.cream,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: FlowraTextStyles.displaySmall.copyWith(
            color: FlowraColors.cream,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: FlowraColors.green500,
          unselectedItemColor: FlowraColors.ink30,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: FlowraTextStyles.overline,
          unselectedLabelStyle: FlowraTextStyles.overline,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: FlowraRadius.lg_,
            side: BorderSide(color: FlowraColors.ink10, width: 1),
          ),
          margin: const EdgeInsets.only(bottom: FlowraSpacing.md),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FlowraColors.green400,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: FlowraSpacing.xxl,
              vertical: FlowraSpacing.lg,
            ),
            shape: RoundedRectangleBorder(borderRadius: FlowraRadius.lg_),
            textStyle: FlowraTextStyles.labelLarge,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: FlowraColors.green400,
            side: const BorderSide(color: FlowraColors.green400),
            padding: const EdgeInsets.symmetric(
              horizontal: FlowraSpacing.xxl,
              vertical: FlowraSpacing.lg,
            ),
            shape: RoundedRectangleBorder(borderRadius: FlowraRadius.lg_),
            textStyle: FlowraTextStyles.labelLarge,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: FlowraColors.green500,
            textStyle: FlowraTextStyles.labelMedium,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: FlowraSpacing.lg,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: FlowraRadius.lg_,
            borderSide: BorderSide(color: FlowraColors.ink10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: FlowraRadius.lg_,
            borderSide: BorderSide(color: FlowraColors.ink10, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: FlowraRadius.lg_,
            borderSide:
                const BorderSide(color: FlowraColors.green400, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: FlowraRadius.lg_,
            borderSide: const BorderSide(color: FlowraColors.red, width: 1.5),
          ),
          labelStyle:
              FlowraTextStyles.labelMedium.copyWith(color: FlowraColors.ink60),
          hintStyle:
              FlowraTextStyles.bodyMedium.copyWith(color: FlowraColors.ink30),
        ),
        dividerTheme: DividerThemeData(
          color: FlowraColors.ink10,
          thickness: 1,
          space: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: FlowraColors.creamDark,
          selectedColor: FlowraColors.green900,
          labelStyle: FlowraTextStyles.labelMedium,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: FlowraRadius.pill_,
            side: BorderSide(color: FlowraColors.ink10),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FlowraColors.darkSurface,
        primaryColor: FlowraColors.green400,
        colorScheme: ColorScheme.dark(
          primary: FlowraColors.green400,
          onPrimary: Colors.white,
          primaryContainer: FlowraColors.green900,
          secondary: FlowraColors.gold400,
          onSecondary: FlowraColors.ink,
          surface: FlowraColors.darkCard,
          onSurface: FlowraColors.darkText,
          error: FlowraColors.red,
          background: FlowraColors.darkSurface,
          onBackground: FlowraColors.darkText,
          outline: FlowraColors.darkBorder,
        ),
        fontFamily: 'DMSans',
        appBarTheme: AppBarTheme(
          backgroundColor: FlowraColors.darkSurface,
          foregroundColor: FlowraColors.darkText,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: FlowraColors.darkCard,
          selectedItemColor: FlowraColors.green400,
          unselectedItemColor: FlowraColors.darkTextMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: FlowraColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: FlowraRadius.lg_,
            side: BorderSide(color: FlowraColors.darkBorder, width: 1),
          ),
        ),
      );
}
