import 'package:flutter/material.dart';

/// OrbixHub design tokens. Direction: warm-industrial B2B SaaS — a light, warm
/// canvas with a graphite command sidebar and a signature tangerine accent.
class AppColors {
  const AppColors._();

  // Brand accent — "Orbix tangerine".
  static const brand = Color(0xFFEC5E12);
  static const brandBright = Color(0xFFFF8A4C);
  static const brandDeep = Color(0xFFC2480A);
  static const brandTint = Color(0xFFFCEDE3); // accent wash on light surfaces

  // Graphite — the dark sidebar / brand panel.
  static const graphite = Color(0xFF15171C);
  static const graphiteHi = Color(0xFF1C1F26);
  static const graphiteLine = Color(0xFF2A2E37);
  static const onGraphite = Color(0xFFF3F2EF);
  static const onGraphiteMuted = Color(0xFF9AA0AB);

  // Light canvas.
  static const canvas = Color(0xFFF6F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF0EEE9);
  static const line = Color(0xFFE7E4DD);

  // Ink.
  static const ink = Color(0xFF1B1D22);
  static const inkMuted = Color(0xFF6B7079);
  static const inkFaint = Color(0xFFA1A6AF);

  // Semantic.
  static const success = Color(0xFF0E9F6E);
  static const successTint = Color(0xFFE3F5EE);
  static const danger = Color(0xFFE5484D);
  static const dangerTint = Color(0xFFFCEAEA);
  static const warning = Color(0xFFE8A302);
  static const warningTint = Color(0xFFFBF0D6);
  static const info = Color(0xFF2E90FA);
}
