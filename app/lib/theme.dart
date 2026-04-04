import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0F1117);
  static const surface = Color(0xFF161B22);
  static const surfaceLight = Color(0xFF21262D);
  static const border = Color(0xFF30363D);
  static const textPrimary = Color(0xFFE1E4E8);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);
  static const accent = Color(0xFF58A6FF);
  static const green = Color(0xFF3FB950);
  static const orange = Color(0xFFD29922);
  static const red = Color(0xFFF85149);
  static const purple = Color(0xFFA371F7);
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.green,
    surface: AppColors.surface,
    error: AppColors.red,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
  ),
  dividerColor: AppColors.border,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textPrimary),
    bodySmall: TextStyle(color: AppColors.textSecondary),
    titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
    labelSmall: TextStyle(color: AppColors.textMuted, fontSize: 11),
  ),
);

const playerColors = [
  Color(0xFF58A6FF),
  Color(0xFFF0883E),
  Color(0xFFA371F7),
  Color(0xFF3FB950),
  Color(0xFFF85149),
  Color(0xFFD29922),
  Color(0xFFDB61A2),
  Color(0xFF79C0FF),
  Color(0xFF7EE787),
  Color(0xFFFFA657),
];

Color getPlayerColor(int trackerId) => playerColors[trackerId % playerColors.length];
