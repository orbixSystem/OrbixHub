import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/sale/domain/sale_payment_split.dart';

/// A divisão do dinheiro da venda: quanto entra no caixa, quanto é troco e
/// quanto fica a receber.
///
/// Esta é a regra que um bug real violava: recebendo menos que o total, o app
/// lançava o TOTAL na gaveta e escrevia "Faltou X" na descrição — a gaveta
/// acusava dinheiro que não entrou e a dívida sumia da carteira de fiado.

void main() {
  SalePaymentSplit split(double total, double recebido, {bool dinheiro = true}) =>
      SalePaymentSplit.of(
          total: total, recebido: recebido, dinheiro: dinheiro);

  group('quitou', () {
    test('recebeu exatamente o total', () {
      final s = split(150, 150);
      expect(s.aLancarNoCaixa, 150);
      expect(s.falta, 0);
      expect(s.troco, 0);
      expect(s.ehFiado, isFalse);
    });

    test('resíduo de centavo não vira dívida', () {
      final s = split(100, 99.999);
      expect(s.falta, 0);
      expect(s.ehFiado, isFalse);
    });
  });

  group('fiado parcial', () {
    test('o caixa recebe o RECEBIDO, não o total', () {
      final s = split(200, 120);
      expect(s.aLancarNoCaixa, 120, reason: 'o bug antigo lançava 200 aqui');
      expect(s.falta, 80);
      expect(s.ehFiado, isTrue);
      expect(s.fiadoIntegral, isFalse);
      expect(s.troco, 0);
    });

    test('centavos fecham a conta', () {
      final s = split(99.90, 50.45);
      expect(s.aLancarNoCaixa, 50.45);
      expect(s.falta, 49.45);
    });
  });

  group('fiado integral', () {
    test('recebeu zero: nada entra na gaveta, tudo é dívida', () {
      final s = split(90, 0);
      expect(s.aLancarNoCaixa, 0);
      expect(s.falta, 90);
      expect(s.ehFiado, isTrue);
      expect(s.fiadoIntegral, isTrue);
    });

    test('valor negativo é tratado como zero, não como saída de caixa', () {
      final s = split(90, -50);
      expect(s.aLancarNoCaixa, 0);
      expect(s.falta, 90);
    });
  });

  group('troco', () {
    test('em dinheiro, o excedente é troco e o caixa recebe só o total', () {
      final s = split(90, 100);
      expect(s.troco, 10);
      expect(
        s.aLancarNoCaixa,
        90,
        reason: 'sem o teto, R\$ 10 de troco inflariam o faturamento',
      );
      expect(s.falta, 0);
      expect(s.ehFiado, isFalse);
    });

    test('em Pix/cartão não existe troco: excedente é digitação errada', () {
      // Ninguém paga "a mais" no Pix — inventar um troco aqui faria o operador
      // devolver dinheiro que nunca entrou.
      final s = split(90, 100, dinheiro: false);
      expect(s.troco, 0);
      expect(s.aLancarNoCaixa, 90);
      expect(s.falta, 0);
    });
  });

  group('bordas', () {
    test('venda zerada (brinde) não é fiado nem gera lançamento', () {
      final s = split(0, 0);
      expect(s.aLancarNoCaixa, 0);
      expect(s.falta, 0);
      expect(s.ehFiado, isFalse);
    });

    test('total negativo é saneado para zero', () {
      final s = split(-10, 0);
      expect(s.total, 0);
      expect(s.falta, 0);
    });

    test('aritmética não acumula deriva de centavo', () {
      final s = split(0.1 + 0.2, 0.3); // 0.30000000000000004 vs 0.3
      expect(s.falta, 0);
      expect(s.troco, 0);
    });
  });
}
