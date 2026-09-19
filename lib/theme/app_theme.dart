import 'package:flutter/material.dart';

class AppTheme {
  static const primaryBlack = Color(0xFF18796B);
  static const accentCrimson = Color(0xFFC85B47);
  static const accentGold = Color(0xFFB88B48);
  static const subtleGray = Color(0xFFF0F8F5);
  static const borderGray = Color(0xFFE5EEEA);
  static const textMain = Color(0xFF263D39);
  static const textMuted = Color(0xFF687C77);
  static const canvas = Color(0xFFFFFDF8);
  static const mint = Color(0xFFDDF6EB);
  static const peach = Color(0xFFFFE8DC);
  static ThemeData lightTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: primaryBlack).copyWith(
      primary: primaryBlack,
      secondary: accentCrimson,
      surface: canvas,
      onSurface: textMain,
      outline: borderGray,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'NotoSansKR',
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'sans-serif'],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.7,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.7,
        ),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 15, height: 1.65),
        bodyMedium: TextStyle(fontSize: 13, height: 1.5),
      ).apply(bodyColor: textMain, displayColor: textMain),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderGray),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderGray),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: mint,
        height: 76,
      ),
      dividerColor: borderGray,
    );
  }

  static ThemeData darkTheme() => lightTheme();
}
