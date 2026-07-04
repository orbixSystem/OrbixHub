import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../ui/neu_tokens.dart';
import 'app_colors.dart';

/// The OrbixHub theme. Display type is Sora (geometric, confident); body/UI is
/// Manrope (clean, humanist-geometric). Components are flat with soft radii,
/// hairline borders and a single tangerine accent.
///
/// Both the light and dark variants are seedable: colors are derived from a
/// [ColorScheme.fromSeed] so the workshop's primary color can re-tint the whole
/// app while remaining legible in either brightness.
class AppTheme {
  const AppTheme._();

  static const radius = 14.0;

  static ThemeData light({Color seed = AppColors.brand}) =>
      _build(Brightness.light, seed);

  static ThemeData dark({Color seed = AppColors.brand}) =>
      _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      // fidelity mantém o primary próximo à cor-semente, tornando cada preset
      // claramente distinto (Azul visivelmente azul, Verde visivelmente verde, etc.).
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

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
      extensions: [
        brightness == Brightness.dark ? NeuTokens.dark() : NeuTokens.light(),
      ],
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.copyWith(
        displaySmall: headline(34),
        headlineMedium: headline(28),
        headlineSmall: headline(23),
        titleLarge: headline(19, FontWeight.w600),
        titleMedium: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        labelLarge: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
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
