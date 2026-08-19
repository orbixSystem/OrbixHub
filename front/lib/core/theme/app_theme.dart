import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/neu_tokens.dart';

/// The OrbixHub theme. Display type is Sora (geometric, confident); body/UI is
/// Manrope (clean, humanist-geometric).
///
/// A paleta neumórfica é gerada a partir de uma cor-semente (o brand primário
/// escolhido pelo tenant em Configurações → Aparência). [NeuTokens.forSeed]
/// deriva canvas, relevo, texto e ação em claro e escuro; Lavanda (seed padrão)
/// reproduz o hand-tuned canônico. Semânticas (sucesso/erro/…) são constantes.
class AppTheme {
  const AppTheme._();

  static const radius = 16.0;

  static ThemeData light({Color seed = NeuTokens.lavanderSeed}) =>
      _build(Brightness.light, seed);

  static ThemeData dark({Color seed = NeuTokens.lavanderSeed}) =>
      _build(Brightness.dark, seed);

  /// Mapeia os tokens neumórficos para os papéis do Material ColorScheme —
  /// assim TODAS as telas legadas (que leem roles do scheme) já rendem na
  /// identidade nova antes mesmo de serem migradas para componentes Neu*.
  static ColorScheme _schemeFrom(NeuTokens neu, Brightness brightness) {
    final light = brightness == Brightness.light;
    // Superfície "cavada" derivada da base do tema (antes era um azul fixo):
    // usada como fill de inputs Material. Mais escura que a base no claro,
    // mais clara no escuro — acompanha qualquer paleta.
    final baseHsl = HSLColor.fromColor(neu.base);
    final sunken = baseHsl
        .withLightness(
          (baseHsl.lightness + (light ? -0.04 : 0.055)).clamp(0.0, 1.0),
        )
        .toColor();
    return ColorScheme(
      brightness: brightness,
      primary: neu.navy,
      onPrimary: neu.onNavy,
      primaryContainer: neu.accentTint,
      onPrimaryContainer: light ? neu.navy : neu.ink,
      secondary: neu.accent,
      onSecondary: light ? Colors.white : neu.onNavy,
      secondaryContainer: neu.accentTint,
      onSecondaryContainer: light ? neu.navy : neu.ink,
      tertiary: neu.info,
      onTertiary: Colors.white,
      tertiaryContainer: neu.infoTint,
      onTertiaryContainer: neu.info,
      error: neu.danger,
      onError: Colors.white,
      errorContainer: neu.dangerTint,
      onErrorContainer: neu.danger,
      surface: neu.base,
      onSurface: neu.ink,
      onSurfaceVariant: neu.inkMuted,
      surfaceContainerLowest: neu.surfaceHi,
      surfaceContainerLow: neu.surface,
      surfaceContainer: neu.surface,
      surfaceContainerHigh: neu.surface,
      surfaceContainerHighest: sunken,
      outline: neu.inkFaint,
      outlineVariant: neu.line,
      shadow: neu.shadowDark,
      scrim: Colors.black54,
      inverseSurface: light ? neu.navy : neu.ink,
      onInverseSurface: light ? neu.onNavy : neu.base,
      inversePrimary: neu.accent,
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _build(Brightness brightness, Color seed) {
    final neu = NeuTokens.forSeed(seed, brightness);
    final scheme = _schemeFrom(neu, brightness);

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    final onSurface = scheme.onSurface;
    final onSurfaceMuted = scheme.onSurfaceVariant;

    final display = GoogleFonts.sora();
    final text = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    TextStyle headline(double size, [FontWeight w = FontWeight.w700]) =>
        display.copyWith(
          fontSize: size,
          fontWeight: w,
          color: onSurface,
          letterSpacing: -0.4,
          height: 1.1,
        );

    return base.copyWith(
      // Tokens do design system neumórfico — disponíveis via `context.neu`
      // em qualquer tela (a migração tela-a-tela lê daqui).
      extensions: [neu],
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.copyWith(
        displaySmall: headline(34),
        headlineMedium: headline(28),
        headlineSmall: headline(23),
        titleLarge: headline(19, FontWeight.w600),
        // 18px: piso de TÍTULO no padrão SysOne. Era 15 — e como titleMedium é
        // o estilo de todo título de card/seção (ChartCard, NeuChartCard,
        // "Análise por região"…), o produto inteiro exibia título em 15px.
        titleMedium: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        // O resto da escala vinha do default do Material, que fica ABAIXO dos
        // pisos SysOne em três degraus: titleSmall/bodyLarge em 16 já servem,
        // mas labelSmall vinha em 11px — abaixo do piso absoluto de 12.
        titleSmall: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.manrope(fontSize: 16, color: onSurface),
        bodyMedium: GoogleFonts.manrope(fontSize: 14, color: onSurface),
        bodySmall: GoogleFonts.manrope(fontSize: 12, color: onSurfaceMuted),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: GoogleFonts.manrope(fontSize: 12, color: onSurfaceMuted),
        labelSmall: GoogleFonts.manrope(fontSize: 12, color: onSurfaceMuted),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        hintStyle: TextStyle(color: onSurfaceMuted),
        labelStyle: TextStyle(color: onSurfaceMuted),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius - 2),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide.none,
        labelStyle: GoogleFonts.manrope(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.manrope(color: scheme.onInverseSurface),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: headline(20, FontWeight.w600),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.surfaceContainerHigh,
        headerForegroundColor: onSurface,
        rangePickerBackgroundColor: scheme.surfaceContainerLowest,
        rangePickerSurfaceTintColor: Colors.transparent,
        rangePickerHeaderBackgroundColor: scheme.surfaceContainerHigh,
        rangePickerHeaderForegroundColor: onSurface,
        rangeSelectionBackgroundColor: scheme.primary.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
        ),
        elevation: 2,
      ),
    );
  }
}
