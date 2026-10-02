import 'package:flutter/material.dart';

class AppTheme {
  static const primaryBlack = Color(0xFF2463B5);
  static const accentCrimson = Color(0xFFD85A46);
  static const accentGold = Color(0xFFE6AF48);
  static const subtleGray = Color(0xFFF0F7FF);
  static const borderGray = Color(0xFFDDE8F2);
  static const textMain = Color(0xFF253247);
  static const textMuted = Color(0xFF596575);
  static const canvas = Color(0xFFFCF9F3);
  static const mint = Color(0xFFE0EFFF);
  static const peach = Color(0xFFFFEFCC);
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
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: mint,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 13,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w500,
            color:
                states.contains(WidgetState.selected)
                    ? primaryBlack
                    : textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? primaryBlack
                    : textMuted,
            size: 26,
          ),
        ),
      ),
      dividerColor: borderGray,
    );
  }

  static ThemeData darkTheme() => lightTheme();
}
