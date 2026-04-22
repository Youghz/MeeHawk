import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MH {
  static const sand = Color(0xFFF5F1E8);
  static const paper = Color(0xFFFFFEFB);
  static const ink = Color(0xFF1A1A1A);
  static const inkSoft = Color(0xFF3D3D3D);
  static const pencil = Color(0xFF6B6B6B);
  static const rule = Color(0xFFD4CFC1);
  static const ruleSoft = Color(0xFFE8E2D2);

  static const ball = Color(0xFFE4662A);
  static const ballSoft = Color(0xFFFBE9DD);

  static const us = Color(0xFF2E7D57);
  static const usSoft = Color(0xFFDDEEE3);
  static const them = Color(0xFFB33A3A);
  static const themSoft = Color(0xFFF3DADA);

  static const good = Color(0xFF2E7D57);
  static const mid = Color(0xFFC88A2E);
  static const bad = Color(0xFFB33A3A);

  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double? letterSpacing,
    FontStyle? fontStyle,
    double? height,
  }) =>
      GoogleFonts.roboto(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        height: height,
      );

  static TextStyle mono({
    double size = 10,
    FontWeight weight = FontWeight.w500,
    Color color = pencil,
    double letterSpacing = 1,
  }) =>
      GoogleFonts.rubik(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle hand({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
  }) =>
      GoogleFonts.caveat(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}

final appTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: MH.paper,
  colorScheme: const ColorScheme.light(
    primary: MH.ink,
    secondary: MH.ball,
    surface: MH.paper,
    error: MH.them,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: MH.paper,
    foregroundColor: MH.ink,
    elevation: 0,
  ),
  textTheme: GoogleFonts.robotoTextTheme().apply(
    bodyColor: MH.ink,
    displayColor: MH.ink,
  ),
  dividerColor: MH.rule,
);
