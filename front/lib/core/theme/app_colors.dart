import 'package:flutter/material.dart';

/// Tokens LEGADOS re-apontados para a paleta neumórfica fixa (lavanda + navy,
/// spec 2026-07-04). O laranja "Orbix tangerine" foi descontinuado; enquanto a
/// migração tela-a-tela não termina, as telas antigas que ainda leem AppColors
/// já rendem em harmonia com a identidade nova. Telas novas usam `context.neu`
/// (NeuTokens) — NÃO use AppColors em código novo.
class AppColors {
  const AppColors._();

  // Brand accent — lavanda/violeta (ex-tangerina).
  static const brand = Color(0xFF767CC0);
  static const brandBright = Color(0xFF9BA2E8);
  static const brandDeep = Color(0xFF575DA8);
  static const brandTint = Color(0xFFDFE1F0); // accent wash on light surfaces

  // Painel escuro (ex-graphite) — navy-roxo da sidebar.
  static const graphite = Color(0xFF2B2F44);
  static const graphiteHi = Color(0xFF383D5B);
  static const graphiteLine = Color(0xFF3D4360);
  static const onGraphite = Color(0xFFF2F3F8);
  static const onGraphiteMuted = Color(0xFF9EA3BC);

  // Canvas claro — lavanda.
  static const canvas = Color(0xFFE6E7EE);
  static const surface = Color(0xFFEDEEF5);
  static const surfaceSunken = Color(0xFFDBDCE8);
  static const line = Color(0xFFD8DAE5);

  // Ink.
  static const ink = Color(0xFF2B2F44);
  static const inkMuted = Color(0xFF7B8094);
  static const inkFaint = Color(0xFFA6AABC);

  // Semantic.
  static const success = Color(0xFF0E9F6E);
  static const successTint = Color(0xFFDDF0E8);
  static const danger = Color(0xFFE5484D);
  static const dangerTint = Color(0xFFF8E2E3);
  static const warning = Color(0xFFCC8F02);
  static const warningTint = Color(0xFFF5ECD3);
  static const info = Color(0xFF2E90FA);
}
