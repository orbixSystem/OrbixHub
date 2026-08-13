import 'package:flutter/material.dart';

/// Tokens LEGADOS re-apontados para a paleta neumórfica fixa (lavanda + navy,
/// spec 2026-07-04). O laranja "Orbix tangerine" foi descontinuado; enquanto a
/// migração tela-a-tela não termina, as telas antigas que ainda leem AppColors
/// já rendem em harmonia com a identidade nova. Telas novas usam `context.neu`
/// (NeuTokens) — NÃO use AppColors em código novo.
class AppColors {
  const AppColors._();

  // Brand accent — lavanda/violeta (ex-tangerina).
  static const brand = Color(0xFF555DB1);
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
  static const inkMuted = Color(0xFF515564);
  static const inkFaint = Color(0xFF5E647D);

  // Deep-space — the dark "azul-noite + ciano" treatment used on the auth
  // screens (login/register/…). Cool, ambient; the tangerine brand stays as a
  // warm focal pop against it.
  static const spaceBg = Color(0xFF080B16);
  static const spaceBg2 = Color(0xFF0C1122);
  static const spaceSurface = Color(0xFF121A30);
  static const spaceSurfaceHi = Color(0xFF18233D);
  static const spaceLine = Color(0xFF243352);
  static const spaceCyan = Color(0xFF38D6F0);
  static const spaceCyanDim = Color(0xFF1C9BBE);
  static const onSpace = Color(0xFFEAF1FC);
  static const onSpaceMuted = Color(0xFF8C9AB8);

  // Semantic.
  static const success = Color(0xFF0A734F);
  static const successTint = Color(0xFFDDF0E8);
  static const danger = Color(0xFFC61C22);
  static const dangerTint = Color(0xFFF8E2E3);
  static const warning = Color(0xFF855D01);
  static const warningTint = Color(0xFFF5ECD3);
  static const info = Color(0xFF0562C7);
}
