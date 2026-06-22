import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Um tema do sistema = uma cor-semente curada. O ColorScheme.fromSeed gera
/// claro e escuro a partir dela; a sidebar grafite é constante em todos.
class ThemePreset {
  final String key;
  final String label;
  final Color seed;
  const ThemePreset(this.key, this.label, this.seed);
}

const kThemePresets = <ThemePreset>[
  ThemePreset('tangerina', 'Tangerina', AppColors.brand), // #EC5E12 (padrão atual)
  ThemePreset('vermelho', 'Vermelho', Color(0xFFD7263D)),
  ThemePreset('azul', 'Azul', Color(0xFF2E6BE6)),
  ThemePreset('verde', 'Verde', Color(0xFF0E9F6E)),
  ThemePreset('roxo', 'Roxo', Color(0xFF7C3AED)),
  ThemePreset('petroleo', 'Petróleo', Color(0xFF0E7C86)),
  ThemePreset('ambar', 'Âmbar', Color(0xFFE8A302)),
];

Color seedForPreset(String? key) {
  for (final p in kThemePresets) {
    if (p.key == key) return p.seed;
  }
  return AppColors.brand;
}

String? presetForSeed(Color seed) {
  for (final p in kThemePresets) {
    if (p.seed.toARGB32() == seed.toARGB32()) return p.key;
  }
  return null;
}
