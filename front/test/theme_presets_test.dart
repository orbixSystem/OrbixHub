import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/theme/app_colors.dart';
import 'package:orbixhub_front/core/theme/theme_presets.dart';

void main() {
  test('tangerina é o default e mapeia para AppColors.brand', () {
    expect(seedForPreset('tangerina').toARGB32(), AppColors.brand.toARGB32());
    expect(seedForPreset(null).toARGB32(), AppColors.brand.toARGB32()); // fallback
    expect(seedForPreset('inexistente').toARGB32(), AppColors.brand.toARGB32());
  });
  test('inclui 7 presets com chaves esperadas', () {
    expect(kThemePresets.map((p) => p.key), containsAll(
      ['tangerina', 'vermelho', 'azul', 'verde', 'roxo', 'petroleo', 'ambar']));
    expect(kThemePresets.length, 7);
  });
  test('presetForSeed faz o caminho inverso', () {
    expect(presetForSeed(seedForPreset('azul')), 'azul');
  });
}
