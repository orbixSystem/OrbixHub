import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/util/masks.dart';

/// Campos de valor precisam RECUSAR o que não é número.
///
/// `keyboardType: numberWithOptions` só sugere o teclado no celular — no desktop
/// e na web não impede nada, e a venda avulsa aceitava letras. Este formatter é
/// a barreira de verdade.
String _apply(TextInputFormatter f, String antes, String depois) => f
    .formatEditUpdate(
      TextEditingValue(text: antes, selection: TextSelection.collapsed(offset: antes.length)),
      TextEditingValue(text: depois, selection: TextSelection.collapsed(offset: depois.length)),
    )
    .text;

void main() {
  group('DecimalInputFormatter (2 casas — dinheiro)', () {
    const f = DecimalInputFormatter();

    test('aceita dígitos', () {
      expect(_apply(f, '', '1'), '1');
      expect(_apply(f, '12', '123'), '123');
    });

    test('recusa letras — o bug relatado na venda avulsa', () {
      expect(_apply(f, '', 'a'), '');
      expect(_apply(f, '10', '10a'), '10');
      expect(_apply(f, '', 'abc'), '');
      expect(_apply(f, '5', '5x0'), '50');
    });

    test('recusa símbolos', () {
      expect(_apply(f, '10', r'10$'), '10');
      expect(_apply(f, '10', '10-'), '10');
      expect(_apply(f, '10', '10 '), '10');
    });

    test('aceita um separador decimal', () {
      expect(_apply(f, '10', '10,'), '10,');
      expect(_apply(f, '10,', '10,5'), '10,5');
      expect(_apply(f, '10,5', '10,50'), '10,50');
    });

    test('normaliza ponto para vírgula (pt-BR)', () {
      expect(_apply(f, '10', '10.'), '10,');
      expect(_apply(f, '10', '10.5'), '10,5');
    });

    test('recusa o segundo separador', () {
      expect(_apply(f, '10,5', '10,5,'), '10,5');
      expect(_apply(f, '10,5', '10,5.'), '10,5');
    });

    test('limita a 2 casas decimais', () {
      expect(_apply(f, '10,50', '10,509'), '10,50');
    });

    test('permite começar pelo separador', () {
      expect(_apply(f, '', ','), ',');
      expect(_apply(f, ',', ',9'), ',9');
    });

    test('permite apagar', () {
      expect(_apply(f, '10,5', '10,'), '10,');
      expect(_apply(f, '10', '1'), '1');
      expect(_apply(f, '1', ''), '');
    });
  });

  group('DecimalInputFormatter(3) — quantidade', () {
    const f = DecimalInputFormatter(3);

    test('aceita 3 casas', () {
      expect(_apply(f, '1,25', '1,250'), '1,250');
    });

    test('barra a 4ª casa', () {
      expect(_apply(f, '1,250', '1,2509'), '1,250');
    });
  });

  group('compatibilidade com o parse do app', () {
    // O app converte vírgula em ponto antes de `double.tryParse`
    // (Validators.positiveNumber e _parseAmount do caixa).
    test('o texto produzido é parseável', () {
      const f = DecimalInputFormatter();
      final texto = _apply(f, '1234,5', '1234,56');
      expect(double.tryParse(texto.replaceAll(',', '.')), 1234.56);
    });
  });
}
