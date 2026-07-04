import 'package:flutter/material.dart';

/// Tokens do design system neumórfico (soft-UI) do OrbixHub.
///
/// Paleta FIXA do produto (decisão do dono — spec 2026-07-04): lavanda clara +
/// navy de contraste. Não há mais seed por tenant. Exposta como
/// [ThemeExtension] para os componentes lerem via `context.neu`.
///
/// Usabilidade primeiro: a ação primária é SEMPRE navy sólido de alto
/// contraste — o relevo neumórfico é textura, nunca o único sinal de
/// affordance.
@immutable
class NeuTokens extends ThemeExtension<NeuTokens> {
  const NeuTokens({
    required this.base,
    required this.surface,
    required this.surfaceHi,
    required this.shadowLight,
    required this.shadowDark,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.line,
    required this.navy,
    required this.navyHover,
    required this.onNavy,
    required this.onNavyMuted,
    required this.accent,
    required this.accentTint,
    required this.success,
    required this.successTint,
    required this.danger,
    required this.dangerTint,
    required this.warning,
    required this.warningTint,
    required this.info,
    required this.infoTint,
    required this.glyphs,
  });

  /// Fundo geral do app (canvas neumórfico).
  final Color base;

  /// Superfície dos cartões (ligeiramente acima da base).
  final Color surface;

  /// Superfície de destaque (hover/realce sutil).
  final Color surfaceHi;

  /// Sombra clara (cima-esquerda) do relevo.
  final Color shadowLight;

  /// Sombra escura (baixo-direita) do relevo.
  final Color shadowDark;

  /// Texto principal.
  final Color ink;

  /// Texto secundário.
  final Color inkMuted;

  /// Texto terciário/placeholder.
  final Color inkFaint;

  /// Linha/divisor sutil.
  final Color line;

  /// Painel/ação primária (alto contraste).
  final Color navy;

  /// Navy em hover/pressed.
  final Color navyHover;

  /// Conteúdo sobre navy.
  final Color onNavy;

  /// Conteúdo secundário sobre navy.
  final Color onNavyMuted;

  /// Acento suave (seleção, links, focos decorativos).
  final Color accent;

  /// Fundo tintado do acento.
  final Color accentTint;

  final Color success;
  final Color successTint;
  final Color danger;
  final Color dangerTint;
  final Color warning;
  final Color warningTint;
  final Color info;
  final Color infoTint;

  /// Paleta de glyphs coloridos (ícones de módulo/categoria), na ordem:
  /// amarelo, laranja, azul, verde, roxo, rosa — como na referência visual.
  final List<Color> glyphs;

  // ---- Raios padrão (spec) ----
  static const double rChip = 12;
  static const double rField = 16;
  static const double rCard = 20;
  static const double rPanel = 28;

  /// Tema claro — lavanda.
  factory NeuTokens.light() => const NeuTokens(
        base: Color(0xFFE6E7EE),
        surface: Color(0xFFEDEEF5),
        surfaceHi: Color(0xFFF4F5FA),
        shadowLight: Color(0xFFFFFFFF),
        shadowDark: Color(0x66B8BCCC),
        ink: Color(0xFF2B2F44),
        inkMuted: Color(0xFF7B8094),
        inkFaint: Color(0xFFA6AABC),
        line: Color(0xFFD8DAE5),
        navy: Color(0xFF2B2F44),
        navyHover: Color(0xFF383D5B),
        onNavy: Color(0xFFF2F3F8),
        onNavyMuted: Color(0xFF9EA3BC),
        accent: Color(0xFF6A70A3),
        accentTint: Color(0xFFDFE1F0),
        success: Color(0xFF0E9F6E),
        successTint: Color(0xFFDDF0E8),
        danger: Color(0xFFE5484D),
        dangerTint: Color(0xFFF8E2E3),
        warning: Color(0xFFCC8F02),
        warningTint: Color(0xFFF5ECD3),
        info: Color(0xFF2E90FA),
        infoTint: Color(0xFFDFECFD),
        glyphs: [
          Color(0xFFF5C518), // amarelo
          Color(0xFFF2762E), // laranja
          Color(0xFF3B82F6), // azul
          Color(0xFF10B981), // verde
          Color(0xFF8B5CF6), // roxo
          Color(0xFFEC4899), // rosa
        ],
      );

  /// Tema escuro — navy.
  factory NeuTokens.dark() => const NeuTokens(
        base: Color(0xFF262A3D),
        surface: Color(0xFF2D3248),
        surfaceHi: Color(0xFF343A54),
        shadowLight: Color(0x3345507A),
        shadowDark: Color(0x8014172A),
        ink: Color(0xFFECEDF5),
        inkMuted: Color(0xFF9BA0B8),
        inkFaint: Color(0xFF6E7390),
        line: Color(0xFF3B4160),
        navy: Color(0xFFE3E5F2),
        navyHover: Color(0xFFF2F3FA),
        onNavy: Color(0xFF262A3D),
        onNavyMuted: Color(0xFF5A5F7C),
        accent: Color(0xFF9BA2DB),
        accentTint: Color(0xFF363C5C),
        success: Color(0xFF34C596),
        successTint: Color(0xFF23372F),
        danger: Color(0xFFF06A6E),
        dangerTint: Color(0xFF3D2528),
        warning: Color(0xFFE8B93E),
        warningTint: Color(0xFF3B3423),
        info: Color(0xFF5CA8FF),
        infoTint: Color(0xFF24314A),
        glyphs: [
          Color(0xFFF5C518),
          Color(0xFFF2762E),
          Color(0xFF60A5FA),
          Color(0xFF34D399),
          Color(0xFFA78BFA),
          Color(0xFFF472B6),
        ],
      );

  /// Sombra dupla do relevo extrudado.
  List<BoxShadow> raised({bool high = false}) {
    final blur = high ? 22.0 : 12.0;
    final offset = high ? 10.0 : 5.0;
    return [
      BoxShadow(
        color: shadowDark,
        blurRadius: blur,
        offset: Offset(offset, offset),
      ),
      BoxShadow(
        color: shadowLight,
        blurRadius: blur,
        offset: Offset(-offset, -offset),
      ),
    ];
  }

  @override
  NeuTokens copyWith() => this;

  @override
  NeuTokens lerp(ThemeExtension<NeuTokens>? other, double t) {
    if (other is! NeuTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return NeuTokens(
      base: c(base, other.base),
      surface: c(surface, other.surface),
      surfaceHi: c(surfaceHi, other.surfaceHi),
      shadowLight: c(shadowLight, other.shadowLight),
      shadowDark: c(shadowDark, other.shadowDark),
      ink: c(ink, other.ink),
      inkMuted: c(inkMuted, other.inkMuted),
      inkFaint: c(inkFaint, other.inkFaint),
      line: c(line, other.line),
      navy: c(navy, other.navy),
      navyHover: c(navyHover, other.navyHover),
      onNavy: c(onNavy, other.onNavy),
      onNavyMuted: c(onNavyMuted, other.onNavyMuted),
      accent: c(accent, other.accent),
      accentTint: c(accentTint, other.accentTint),
      success: c(success, other.success),
      successTint: c(successTint, other.successTint),
      danger: c(danger, other.danger),
      dangerTint: c(dangerTint, other.dangerTint),
      warning: c(warning, other.warning),
      warningTint: c(warningTint, other.warningTint),
      info: c(info, other.info),
      infoTint: c(infoTint, other.infoTint),
      glyphs: glyphs,
    );
  }
}

/// Acesso curto aos tokens: `context.neu`.
extension NeuContext on BuildContext {
  NeuTokens get neu =>
      Theme.of(this).extension<NeuTokens>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? NeuTokens.dark()
          : NeuTokens.light());
}
