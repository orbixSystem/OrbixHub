import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/theme_presets.dart';
import 'package:orbixhub_front/core/ui/neu_tokens.dart';

void main() {
  test('lavanda é o default e mapeia para o seed canônico', () {
    expect(seedForPreset('lavanda').toARGB32(),
        NeuTokens.lavanderSeed.toARGB32());
    expect(seedForPreset(null).toARGB32(),
        NeuTokens.lavanderSeed.toARGB32()); // fallback
    expect(seedForPreset('inexistente').toARGB32(),
        NeuTokens.lavanderSeed.toARGB32());
  });
  test('inclui 8 presets com chaves esperadas', () {
    expect(
        kThemePresets.map((p) => p.key),
        containsAll([
          'lavanda',
          'azul',
          'petroleo',
          'verde',
          'tangerina',
          'rosa',
          'vermelho',
          'ardosia',
        ]));
    expect(kThemePresets.length, 8);
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
