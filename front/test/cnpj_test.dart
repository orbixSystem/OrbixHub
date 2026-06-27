import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/util/cnpj.dart';

void main() {
  group('isValidCnpj', () {
    test('aceita CNPJs válidos (com e sem máscara)', () {
      expect(isValidCnpj('11222333000181'), isTrue);
      expect(isValidCnpj('11.222.333/0001-81'), isTrue);
      expect(isValidCnpj('19.131.243/0001-97'), isTrue);
    });
    test('rejeita dígitos verificadores errados', () {
      expect(isValidCnpj('11222333000180'), isFalse);
    });
    test('rejeita tamanho errado e vazio', () {
      expect(isValidCnpj('1122233300018'), isFalse);
      expect(isValidCnpj(''), isFalse);
      expect(isValidCnpj(null), isFalse);
    });
    test('rejeita sequências de dígito único', () {
      expect(isValidCnpj('00000000000000'), isFalse);
      expect(isValidCnpj('11111111111111'), isFalse);
    });
  });

  group('formatCnpj', () {
    test('formata 14 dígitos', () {
      expect(formatCnpj('11222333000181'), '11.222.333/0001-81');
    });
    test('formata parcialmente enquanto digita', () {
      expect(formatCnpj('11222'), '11.222');
    });
  });

  test('normalizeCnpj remove máscara', () {
    expect(normalizeCnpj('11.222.333/0001-81'), '11222333000181');
  });
}
