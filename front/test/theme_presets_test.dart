import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/theme_presets.dart';
import 'package:orbixhub_front/core/ui/neu_tokens.dart';

void main() {
  test('roxo é o default (roxo anterior) e mapeia para o seed canônico', () {
    expect(kThemePresets.first.key, 'roxo');
    expect(seedForPreset('roxo').toARGB32(), NeuTokens.lavanderSeed.toARGB32());
    expect(seedForPreset(null).toARGB32(),
        NeuTokens.lavanderSeed.toARGB32()); // fallback
    expect(seedForPreset('inexistente').toARGB32(),
        NeuTokens.lavanderSeed.toARGB32());
  });
  test('inclui 10 presets com chaves esperadas', () {
    expect(
        kThemePresets.map((p) => p.key),
        containsAll([
          'roxo',
          'azul',
          'petroleo',
          'verde',
          'tangerina',
          'rosa',
          'vermelho',
          'amarelo',
          'ardosia',
          'mono',
        ]));
    expect(kThemePresets.length, 10);
  });
  test('mono (Preto & Branco) é monocromático: ação preta no claro, branca no escuro', () {
    final seed = seedForPreset('mono');
    final light = NeuTokens.forSeed(seed, Brightness.light);
    final dark = NeuTokens.forSeed(seed, Brightness.dark);
    // Ação escura no claro, clara no escuro (contraste invertido).
    expect(light.navy.computeLuminance(), lessThan(0.15));
    expect(dark.navy.computeLuminance(), greaterThan(0.8));
    // Canvas neutro (sem matiz perceptível).
    expect(HSLColor.fromColor(light.base).saturation, lessThan(0.1));
  });
  test('presetForSeed faz o caminho inverso', () {
    expect(presetForSeed(seedForPreset('azul')), 'azul');
  });
  test('forSeed gera paletas distintas por matiz, mantendo semânticas', () {
    final azul = NeuTokens.forSeed(seedForPreset('azul'), Brightness.light);
    final verde = NeuTokens.forSeed(seedForPreset('verde'), Brightness.light);
    // A ação primária muda com a paleta...
    expect(azul.navy.toARGB32(), isNot(verde.navy.toARGB32()));
    // ...mas o vermelho de erro é constante (semântica preservada).
    expect(azul.danger.toARGB32(), verde.danger.toARGB32());
  });
}
