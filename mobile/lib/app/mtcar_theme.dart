import 'package:flutter/material.dart';

class MtColors {
  static const red = Color(0xFFE10600);
  static const redBright = Color(0xFFF20A1A);
  static const redDark = Color(0xFF9D0007);
  static const graphite = Color(0xFF2B2F36);
  static const ink = Color(0xFF111827);
  static const lightBg = Color(0xFFF7F7F8);
  static const darkBg = Color(0xFF0E1116);
  static const darkCard = Color(0xFF171B22);
  static const green = Color(0xFF168A4A);
  static const amber = Color(0xFFD97706);
}

ThemeData mtLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MtColors.red,
    brightness: Brightness.light,
    primary: MtColors.red,
    secondary: MtColors.redDark,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: MtColors.lightBg,
    dividerColor: const Color(0xFFCDD2D9),
    splashColor: MtColors.red.withOpacity(.05),
    highlightColor: MtColors.red.withOpacity(.03),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.black.withOpacity(.05)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.black.withOpacity(.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MtColors.red, width: 1.35),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MtColors.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}

ThemeData mtDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MtColors.red,
    brightness: Brightness.dark,
    primary: MtColors.redBright,
    secondary: const Color(0xFFFF514A),
    surface: MtColors.darkCard,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: MtColors.darkBg,
    dividerColor: const Color(0xFF353A43),
    splashColor: Colors.white.withOpacity(.03),
    cardTheme: CardThemeData(
      color: MtColors.darkCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withOpacity(.06)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF171B22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(.07)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(.07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MtColors.redBright, width: 1.35),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MtColors.red,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}
