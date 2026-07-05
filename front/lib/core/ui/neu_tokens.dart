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
        // Ação primária = ROXO principal (não o navy escuro — botões "pretos"
        // liam como quebrados). O navy escuro segue nos painéis (sidebar/NeuPanel).
        navy: Color(0xFF6C72C4),
        navyHover: Color(0xFF7B81D4),
        onNavy: Color(0xFFFFFFFF),
        onNavyMuted: Color(0xFFD8DAF2),
        accent: Color(0xFF767CC0),
        accentTint: Color(0xFFDFE1F0),
        success: Color(0xFF0E9F6E),
        successTint: Color(0xFFDDF0E8),
        danger: Color(0xFFE5484D),
        dangerTint: Color(0xFFF8E2E3),
        warning: Color(0xFFCC8F02),
        warningTint: Color(0xFFF5ECD3),
        info: Color(0xFF2E90FA),
        infoTint: Color(0xFFDFECFD),
        glyphs: _glyphsLight,
      );

  /// Tema escuro — navy-roxo (mescla lavanda, como a referência).
  factory NeuTokens.dark() => const NeuTokens(
        base: Color(0xFF23263B),
        surface: Color(0xFF2C3050),
        surfaceHi: Color(0xFF373C63),
        shadowLight: Color(0x40525C96),
        shadowDark: Color(0x8612142A),
        ink: Color(0xFFEDEEFA),
        inkMuted: Color(0xFFA2A7CB),
        inkFaint: Color(0xFF6F7499),
        line: Color(0xFF3E4370),
        navy: Color(0xFFAEB4F0),
        navyHover: Color(0xFFC2C7F7),
        onNavy: Color(0xFF1E2136),
        onNavyMuted: Color(0xFF4C5178),
        accent: Color(0xFFA5ABE8),
        accentTint: Color(0xFF3B4066),
        success: Color(0xFF3ECFA0),
        successTint: Color(0xFF243B34),
        danger: Color(0xFFF0787C),
        dangerTint: Color(0xFF3F282D),
        warning: Color(0xFFE8BC52),
        warningTint: Color(0xFF3B3526),
        info: Color(0xFF6FB1FF),
        infoTint: Color(0xFF283452),
        glyphs: _glyphsDark,
      );

  // ---- Paletas por cor-semente ----------------------------------------
  //
  // A partir da spec de temas (2026-07): a paleta neumórfica deixa de ser fixa.
  // Uma cor-semente (o brand primário) gera TODA a paleta — canvas, relevo,
  // texto e ação — em claro e escuro, mantendo o mesmo "esqueleto" soft-UI.
  // As cores semânticas (sucesso/erro/aviso/info) e os glyphs de módulo
  // permanecem constantes: verde é sempre verde, vermelho é sempre vermelho.

  /// Seed da paleta canônica (Lavanda) — reproduz o hand-tuned de [light]/[dark].
  static const lavanderSeed = Color(0xFF6C72C4);

  static const _glyphsLight = <Color>[
    Color(0xFF8B5CF6), // violeta
    Color(0xFF5B8DEF), // azul
    Color(0xFF2DB9A8), // teal
    Color(0xFFE86FA8), // rosa
    Color(0xFFD9A13B), // âmbar suave
    Color(0xFF818CF8), // índigo
  ];

  static const _glyphsDark = <Color>[
    Color(0xFFA78BFA), // violeta
    Color(0xFF7CA6F7), // azul
    Color(0xFF4ED0BF), // teal
    Color(0xFFF08BBE), // rosa
    Color(0xFFE3B45C), // âmbar suave
    Color(0xFF97A0FA), // índigo
  ];

  /// Monta os tokens para uma [seed] + [brightness]. Lavanda usa a paleta
  /// hand-tuned canônica; as demais são derivadas mantendo o mesmo esqueleto.
  static NeuTokens forSeed(Color seed, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (seed.toARGB32() == lavanderSeed.toARGB32()) {
      return dark ? NeuTokens.dark() : NeuTokens.light();
    }
    // Seed acromático (cinza/preto) → tema monocromático "Preto & Branco":
    // ação preta no claro, branca no escuro. Sem matiz para tingir.
    if (HSLColor.fromColor(seed).saturation < 0.08) {
      return dark ? _monoDark() : _monoLight();
    }
    return dark ? _deriveDark(seed) : _deriveLight(seed);
  }

  /// Tema monocromático claro: neumorphism em cinzas neutros + ação preta.
  static NeuTokens _monoLight() => const NeuTokens(
        base: Color(0xFFE7E7E8),
        surface: Color(0xFFEEEEEF),
        surfaceHi: Color(0xFFF6F6F7),
        shadowLight: Color(0xFFFFFFFF),
        shadowDark: Color(0x66AEAEB2),
        ink: Color(0xFF1E1E20),
        inkMuted: Color(0xFF6C6C71),
        inkFaint: Color(0xFF9B9B9F),
        line: Color(0xFFD6D6D8),
        navy: Color(0xFF242426),
        navyHover: Color(0xFF3A3A3D),
        onNavy: Color(0xFFFFFFFF),
        onNavyMuted: Color(0xFFC9C9CB),
        accent: Color(0xFF3A3A3D),
        accentTint: Color(0xFFDCDCDE),
        success: Color(0xFF0E9F6E),
        successTint: Color(0xFFDDF0E8),
        danger: Color(0xFFE5484D),
        dangerTint: Color(0xFFF8E2E3),
        warning: Color(0xFFCC8F02),
        warningTint: Color(0xFFF5ECD3),
        info: Color(0xFF2E90FA),
        infoTint: Color(0xFFDFECFD),
        glyphs: _glyphsLight,
      );

  /// Tema monocromático escuro: canvas quase preto + ação branca.
  static NeuTokens _monoDark() => const NeuTokens(
        base: Color(0xFF19191B),
        surface: Color(0xFF232325),
        surfaceHi: Color(0xFF2C2C2F),
        shadowLight: Color(0x403A3A3D),
        shadowDark: Color(0x8C09090A),
        ink: Color(0xFFF3F3F4),
        inkMuted: Color(0xFFA9A9AD),
        inkFaint: Color(0xFF6E6E73),
        line: Color(0xFF343437),
        navy: Color(0xFFF0F0F1),
        navyHover: Color(0xFFFFFFFF),
        onNavy: Color(0xFF19191B),
        onNavyMuted: Color(0xFF4A4A4D),
        accent: Color(0xFFE6E6E8),
        accentTint: Color(0xFF303033),
        success: Color(0xFF3ECFA0),
        successTint: Color(0xFF243B34),
        danger: Color(0xFFF0787C),
        dangerTint: Color(0xFF3F282D),
        warning: Color(0xFFE8BC52),
        warningTint: Color(0xFF3B3526),
        info: Color(0xFF6FB1FF),
        infoTint: Color(0xFF283452),
        glyphs: _glyphsDark,
      );

  static Color _hsl(double h, double s, double l, [double a = 1]) =>
      HSLColor.fromAHSL(a, h % 360, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0))
          .toColor();

  /// Deriva a paleta clara de uma cor-semente, tingindo sutilmente o canvas
  /// (base/superfície) com o matiz e normalizando o brilho da ação primária
  /// para contraste consistente entre matizes.
  static NeuTokens _deriveLight(Color seed) {
    final s = HSLColor.fromColor(seed);
    final h = s.hue;
    final navSat = s.saturation.clamp(0.32, 0.85);
    final navy = _hsl(h, navSat, 0.575);
    // Texto sobre a ação: branco por padrão; escuro só se o navy ficar claro.
    final whiteOnNavy = navy.computeLuminance() <= 0.62;
    final onNavy =
        whiteOnNavy ? const Color(0xFFFFFFFF) : const Color(0xFF2B2F44);
    return NeuTokens(
      base: _hsl(h, 0.13, 0.915),
      surface: _hsl(h, 0.22, 0.945),
      surfaceHi: _hsl(h, 0.30, 0.968),
      shadowLight: const Color(0xFFFFFFFF),
      shadowDark: _hsl(h, 0.22, 0.70, 0.40),
      ink: _hsl(h, 0.24, 0.205),
      inkMuted: _hsl(h, 0.11, 0.53),
      inkFaint: _hsl(h, 0.11, 0.69),
      line: _hsl(h, 0.16, 0.855),
      navy: navy,
      navyHover: _hsl(h, navSat, 0.645),
      onNavy: onNavy,
      onNavyMuted:
          whiteOnNavy ? _hsl(h, 0.45, 0.88) : _hsl(h, 0.30, 0.38),
      accent: _hsl(h, (s.saturation * 0.9).clamp(0.34, 0.72), 0.56),
      accentTint: _hsl(h, 0.42, 0.90),
      success: const Color(0xFF0E9F6E),
      successTint: const Color(0xFFDDF0E8),
      danger: const Color(0xFFE5484D),
      dangerTint: const Color(0xFFF8E2E3),
      warning: const Color(0xFFCC8F02),
      warningTint: const Color(0xFFF5ECD3),
      info: const Color(0xFF2E90FA),
      infoTint: const Color(0xFFDFECFD),
      glyphs: _glyphsLight,
    );
  }

  /// Deriva a paleta escura: navy vira uma tinta CLARA do matiz (ação de alto
  /// contraste sobre o canvas escuro), base/superfície escuras tingidas.
  static NeuTokens _deriveDark(Color seed) {
    final s = HSLColor.fromColor(seed);
    final h = s.hue;
    final navSat = s.saturation.clamp(0.45, 0.85);
    final navy = _hsl(h, navSat, 0.80);
    final onNavy = navy.computeLuminance() > 0.55
        ? const Color(0xFF1E2136)
        : const Color(0xFFFFFFFF);
    return NeuTokens(
      base: _hsl(h, 0.28, 0.175),
      surface: _hsl(h, 0.26, 0.24),
      surfaceHi: _hsl(h, 0.25, 0.305),
      shadowLight: _hsl(h, 0.30, 0.45, 0.25),
      shadowDark: _hsl(h, 0.45, 0.055, 0.52),
      ink: _hsl(h, 0.40, 0.955),
      inkMuted: _hsl(h, 0.22, 0.71),
      inkFaint: _hsl(h, 0.16, 0.52),
      line: _hsl(h, 0.28, 0.34),
      navy: navy,
      navyHover: _hsl(h, navSat, 0.865),
      onNavy: onNavy,
      onNavyMuted: _hsl(h, 0.30, 0.47),
      accent: _hsl(h, 0.58, 0.78),
      accentTint: _hsl(h, 0.30, 0.30),
      success: const Color(0xFF3ECFA0),
      successTint: const Color(0xFF243B34),
      danger: const Color(0xFFF0787C),
      dangerTint: const Color(0xFF3F282D),
      warning: const Color(0xFFE8BC52),
      warningTint: const Color(0xFF3B3526),
      info: const Color(0xFF6FB1FF),
      infoTint: const Color(0xFF283452),
      glyphs: _glyphsDark,
    );
  }

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
