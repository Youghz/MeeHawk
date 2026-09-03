import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MH {
  // Surfaces — dark
  static const paper = Color(0xFF0D0F14);
  static const sand = Color(0xFF161B24);

  // Text
  static const ink = Color(0xFFEAEEF5);
  static const inkSoft = Color(0xFFB2BACB);
  static const pencil = Color(0xFF5C6577);

  // Borders
  static const rule = Color(0xFF252D3D);
  static const ruleSoft = Color(0xFF1A2030);

  // Accent
  static const ball = Color(0xFFFF5C26);
  static const ballSoft = Color(0x14FF5C26);

  // Teams
  static const them = Color(0xFF4B8EFF);
  static const themSoft = Color(0x144B8EFF);
  static const us = Color(0xFFFFB020);
  static const usSoft = Color(0x14FFB020);

  // Status
  static const good = Color(0xFF22C55E);
  static const mid = Color(0xFFF59E0B);
  static const bad = Color(0xFFEF4444);
  static const badSoft = Color(0x14EF4444);

  // Analytics markers — pastel variants of good/bad, legible as small dots
  // on the court background where the saturated status colours vibrate.
  static const aceDot = Color(0xFF86EFAC);
  static const faultDot = Color(0xFFFCA5A5);

  // Sand court surface, seen through the canvas painter
  static const courtSurface = Color(0xFFC4A872);
  static const courtBorder = Color(0xFF7A5C30);
  static const courtTexture = Color(0xFFA88848);
  static const courtLine = Color(0xFF5C4020);

  // Scrim behind full-court prompts. Two levels: light enough to keep the
  // court readable, heavy enough to stop interaction reading as available.
  static const scrim = Color(0x8C141210);
  static const scrimStrong = Color(0xC6141210);

  // Spacing scale
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
      GoogleFonts.inter(
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
      GoogleFonts.robotoMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // hand kept for API compatibility — maps to Inter
  static TextStyle hand({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: MH.paper,
  colorScheme: const ColorScheme.dark(
    primary: MH.ball,
    secondary: MH.them,
    surface: MH.sand,
    error: MH.bad,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: MH.paper,
    foregroundColor: MH.ink,
    elevation: 0,
  ),
  textTheme: GoogleFonts.interTextTheme().apply(
    bodyColor: MH.ink,
    displayColor: MH.ink,
  ),
  dividerColor: MH.rule,
);
