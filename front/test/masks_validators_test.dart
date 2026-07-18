import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/util/masks.dart';
import 'package:orbixhub_front/core/util/validators.dart';

void main() {
  group('telefone', () {
    test('formata fixo (10) e celular (11)', () {
      expect(formatPhone('1134567890'), '(11) 3456-7890');
      expect(formatPhone('11912345678'), '(11) 91234-5678');
      expect(formatPhone('11'), '(11');
    });
    test('valida 10/11 dígitos', () {
      expect(isValidPhone('1134567890'), isTrue);
      expect(isValidPhone('11912345678'), isTrue);
      expect(isValidPhone('12345'), isFalse);
    });
  });

  group('CPF', () {
    test('valida DV e rejeita repetidos', () {
      expect(isValidCpf('529.982.247-25'), isTrue);
      expect(isValidCpf('111.111.111-11'), isFalse);
      expect(isValidCpf('529.982.247-20'), isFalse);
    });
    test('formata parcial', () => expect(formatCpf('5299822'), '529.982.2'));
  });

  group('documento por tipo', () {
    test('PF usa CPF, PJ usa CNPJ; vazio é válido (opcional)', () {
      expect(isValidDocument('', 'PF'), isTrue);
      expect(isValidDocument('529.982.247-25', 'PF'), isTrue);
      expect(isValidDocument('529.982.247-25', 'PJ'), isFalse);
    });
  });

  group('CEP + placa', () {
    test('CEP 8 dígitos', () {
      expect(formatCep('01001000'), '01001-000');
      expect(isValidCep('01001000'), isTrue);
      expect(isValidCep('123'), isFalse);
    });
    test('placa antiga e Mercosul', () {
      expect(isValidPlate('ABC1234'), isTrue);
      expect(isValidPlate('ABC1D23'), isTrue);
      expect(isValidPlate('AB12'), isFalse);
    });
  });

  group('Validators', () {
    test('required', () {
      expect(Validators.required('Nome')(''), isNotNull);
      expect(Validators.required('Nome')('  '), isNotNull);
      expect(Validators.required('Nome')('João'), isNull);
    });
    test('phone obrigatório vs opcional', () {
      expect(Validators.phone(optional: false)(''), isNotNull);
      expect(Validators.phone()(''), isNull);
      expect(Validators.phone()('12345'), isNotNull);
      expect(Validators.phone()('11912345678'), isNull);
    });
    test('email', () {
      expect(Validators.email()('a@b.c'), isNull);
      expect(Validators.email()('nope'), isNotNull);
      expect(Validators.email()(''), isNull);
    });
    test('positiveNumber aceita vírgula', () {
      expect(Validators.positiveNumber()('10,5'), isNull);
      expect(Validators.positiveNumber()('0'), isNotNull);
      expect(Validators.positiveNumber()('abc'), isNotNull);
    });
    test('combine devolve o 1º erro', () {
      final v = Validators.combine([
        Validators.required('Nome'),
        Validators.minLength(3, 'Nome'),
      ]);
      expect(v(''), contains('obrigatório'));
      expect(v('ab'), contains('mínimo'));
      expect(v('João'), isNull);
    });
  });
}
