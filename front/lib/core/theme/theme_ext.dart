import 'package:flutter/material.dart';

/// Extensão em [BuildContext] que expõe tokens de cor adaptativos ao tema atual.
/// Substitui o uso direto de [AppColors] nos widgets — equivalente a
/// variáveis CSS que alternam entre modo claro e escuro automaticamente.
///
/// Uso: `context.textPrimary`, `context.surface`, `context.borderColor`, …
extension ThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Texto ──────────────────────────────────────────────────────────────────
  /// Texto principal (headings, valores).
  Color get textPrimary => cs.onSurface;

  /// Texto secundário (labels, metadados).
  Color get textSecondary => cs.onSurfaceVariant;

  /// Texto desabilitado / placeholder.
  Color get textDisabled => cs.onSurface.withValues(alpha: 0.35);

  /// Texto de erro.
  Color get textError => cs.error;

  // ── Superfícies ────────────────────────────────────────────────────────────
  /// Superfície de card / painel.
  Color get surface => cs.surface;

  /// Fundo da tela (canvas).
  Color get canvas => cs.surfaceContainerLow;

  /// Superfície levemente elevada (hover, container interno).
  Color get surfaceHigher => cs.surfaceContainerHigh;

  // ── Bordas ─────────────────────────────────────────────────────────────────
  /// Borda sutil (divisores, inputs, cards).
  Color get borderColor => cs.outlineVariant;

  /// Borda de destaque (foco, seleção).
  Color get borderStrong => cs.outline;

  // ── Acento (brand) ─────────────────────────────────────────────────────────
  /// Cor primária do tema (derivada do seed de marca, adapta ao modo escuro).
  Color get accent => cs.primary;

  /// Texto/ícone sobre a cor de acento.
  Color get onAccent => cs.onPrimary;

  /// Superfície de acento (fill suave para seleção/hover).
  Color get accentSubtle => cs.primaryContainer;

  /// Texto sobre superfície de acento sutil.
  Color get onAccentSubtle => cs.onPrimaryContainer;
}
