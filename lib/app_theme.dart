import 'package:flutter/material.dart';

class AppTheme {
  static const Color emerald = Color(0xFF0F6B57);
  static const Color deepEmerald = Color(0xFF083E34);
  static const Color sand = Color(0xFFF5F0E6);
  static const Color gold = Color(0xFFB88A2A);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.light,
      surface: const Color(0xFFFBFAF6),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFBFAF6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: emerald.withValues(alpha: .14),
      ),
      fontFamily: null,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        brightness: Brightness.dark,
      ),
    );
  }
}
