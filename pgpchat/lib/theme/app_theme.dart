import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF137FEC);

  // Background
  static const Color backgroundDark = Color(0xFF101922);
  static const Color backgroundLight = Color(0xFFF6F7F8);

  // Surface
  static const Color surfaceDark = Color(0xFF1A2530);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Surface variants
  static const Color surfaceHoverDark = Color(0xFF233140);
  static const Color surfaceCardDark = Color(0xFF1A2634);

  // Text
  static const Color textMainDark = Color(0xFFF8FAFC);
  static const Color textMainLight = Color(0xFF0F172A);
  static const Color textSubDark = Color(0xFF94A3B8);
  static const Color textSubLight = Color(0xFF64748B);

  // Borders
  static const Color borderDark = Color(0xFF2A3B4C);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Slate shades
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color purple500 = Color(0xFF8B5CF6);
  static const Color yellow400 = Color(0xFFFACC15);
  static const Color yellow600 = Color(0xFFCA8A04);

  // Key gen success screen
  static const Color successPrimary = Color(0xFF13EC5B);
  static const Color successBackgroundDark = Color(0xFF102216);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textMainDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textMainDark,
          letterSpacing: -0.015,
        ),
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
    );
  }
}
