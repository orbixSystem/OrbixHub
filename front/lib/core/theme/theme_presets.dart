import 'package:flutter/material.dart';

import '../ui/neu_tokens.dart';

/// Um tema do sistema = uma cor-semente curada. A partir dela [NeuTokens.forSeed]
/// gera toda a paleta neumórfica (canvas, relevo, texto, ação) em claro e escuro.
/// A escolha é do tenant (Configurações → Aparência) e vale para toda a oficina.
class ThemePreset {
  final String key;
  final String label;
  final Color seed;
  const ThemePreset(this.key, this.label, this.seed);
}

/// Cores pré-definidas oferecidas na tela de Aparência. Lavanda é o padrão
/// (reproduz o hand-tuned canônico); as demais são derivadas do seed.
const kThemePresets = <ThemePreset>[
  ThemePreset('roxo', 'Roxo', NeuTokens.lavanderSeed), // padrão (roxo anterior)
  ThemePreset('azul', 'Azul', Color(0xFF3F6FE5)),
  ThemePreset('petroleo', 'Petróleo', Color(0xFF0E8C8C)),
  ThemePreset('verde', 'Verde', Color(0xFF1E9E63)),
  ThemePreset('tangerina', 'Tangerina', Color(0xFFE8631A)),
  ThemePreset('rosa', 'Rosa', Color(0xFFDB4B8A)),
  ThemePreset('vermelho', 'Vermelho', Color(0xFFDE3B4B)),
  ThemePreset('ardosia', 'Ardósia', Color(0xFF5C6B87)),
];

/// Seed do preset (por chave). Desconhecido/nulo → Lavanda (padrão).
Color seedForPreset(String? key) {
  for (final p in kThemePresets) {
    if (p.key == key) return p.seed;
  }
  return NeuTokens.lavanderSeed;
}

/// Chave do preset a partir de um seed exato (usado ao ler `primaryColor` hex).
String? presetForSeed(Color seed) {
  for (final p in kThemePresets) {
    if (p.seed.toARGB32() == seed.toARGB32()) return p.key;
  }
  return null;
}
