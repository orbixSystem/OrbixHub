import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_format.dart';

/// Testes do balanço do caixa — as regras de negócio:
///
/// - Recebido = OS pagas + vendas avulsas (excluindo estornos)
/// - Saídas = saques (sangria) + despesas (excluindo estornos)
/// - Depósitos = suprimentos (excluindo estornos)
/// - Pendente = soma dos totais das OS sem receber
/// - Saldo = Recebido + Depósitos - Saídas
///
/// "Depósito" é dinheiro que o dono injetou no caixa (suprimento).
/// "Saque" é dinheiro que o dono retirou do caixa (sangria).
/// Entries estornadas (reversedAt != null) não contam em nada.

typedef _E = ({String category, String? reversedAt, Object? amount});

_E _entry(String category, Object amount, {bool reversed = false}) => (
      category: category,
      reversedAt: reversed ? '2026-09-15T12:00:00Z' : null,
      amount: amount,
    );

void main() {
  group('computeBalance', () {
    test('cenário vazio — tudo zerado', () {
      final b = computeBalance(entries: [], pendingOsTotals: []);
      expect(b.recebido, 0);
      expect(b.saidas, 0);
      expect(b.depositos, 0);
      expect(b.pendente, 0);
      expect(b.saldo, 0);
    });

    test('recebido soma os_payment + venda_avulsa', () {
      final b = computeBalance(
        entries: [
          _entry('os_payment', '350.00'),
          _entry('os_payment', '200.00'),
          _entry('venda_avulsa', '150.00'),
        ],
        pendingOsTotals: [],
      );
      expect(b.recebido, 700.0);
      expect(b.saidas, 0);
      expect(b.depositos, 0);
      expect(b.saldo, 700.0); // 700 + 0 - 0
    });

    test('recebido NÃO inclui suprimento (depósito)', () {
      final b = computeBalance(
        entries: [
          _entry('os_payment', '500.00'),
          _entry('suprimento', '200.00'), // depósito, não receita
        ],
        pendingOsTotals: [],
      );
      expect(b.recebido, 500.0);
      expect(b.depositos, 200.0);
      // Saldo = 500 + 200 - 0 = 700
      expect(b.saldo, 700.0);
    });

    test('saídas soma sangria + despesa', () {
      final b = computeBalance(
        entries: [
          _entry('sangria', '80.00'),
          _entry('despesa', '120.00'),
        ],
        pendingOsTotals: [],
      );
      expect(b.saidas, 200.0);
      expect(b.recebido, 0);
      // Saldo = 0 + 0 - 200 = -200
      expect(b.saldo, -200.0);
    });

    test('depósitos são apenas suprimentos', () {
      final b = computeBalance(
        entries: [
          _entry('suprimento', '300.00'),
          _entry('suprimento', '100.00'),
        ],
        pendingOsTotals: [],
      );
      expect(b.depositos, 400.0);
      expect(b.recebido, 0);
      expect(b.saidas, 0);
      expect(b.saldo, 400.0); // 0 + 400 - 0
    });

    test('pendente soma totais das OS pendentes', () {
      final b = computeBalance(
        entries: [],
        pendingOsTotals: ['250.00', '890.00', '120.00'],
      );
      expect(b.pendente, 1260.0);
      // Pendente NÃO entra no saldo
      expect(b.saldo, 0);
    });

    test('entries estornadas são ignoradas', () {
      final b = computeBalance(
        entries: [
          _entry('os_payment', '500.00'),
          _entry('os_payment', '300.00', reversed: true), // estornada
          _entry('sangria', '100.00'),
          _entry('sangria', '50.00', reversed: true), // estornada
          _entry('suprimento', '200.00', reversed: true), // estornada
        ],
        pendingOsTotals: [],
      );
      expect(b.recebido, 500.0); // só a não-estornada
      expect(b.saidas, 100.0); // só a não-estornada
      expect(b.depositos, 0); // estornada
      expect(b.saldo, 400.0); // 500 + 0 - 100
    });

    test('saldo = recebido + depósitos - saídas (cenário completo)', () {
      final b = computeBalance(
        entries: [
          _entry('os_payment', '350.00'),
          _entry('os_payment', '540.00'),
          _entry('venda_avulsa', '150.00'),
          _entry('suprimento', '200.00'),
          _entry('sangria', '80.00'),
          _entry('despesa', '100.00'),
        ],
        pendingOsTotals: ['250.00', '890.00', '120.00'],
      );
      // Recebido = 350 + 540 + 150 = 1040
      expect(b.recebido, 1040.0);
      // Saídas = 80 + 100 = 180
      expect(b.saidas, 180.0);
      // Depósitos = 200
      expect(b.depositos, 200.0);
      // Pendente = 1260
      expect(b.pendente, 1260.0);
      // Saldo = 1040 + 200 - 180 = 1060
      expect(b.saldo, 1060.0);
    });

    test('aceita valores como num (não só String)', () {
      final b = computeBalance(
        entries: [
          _entry('os_payment', 250),
          _entry('sangria', 50.5),
        ],
        pendingOsTotals: [100, 200.50],
      );
      expect(b.recebido, 250.0);
      expect(b.saidas, 50.5);
      expect(b.pendente, 300.5);
      expect(b.saldo, 199.5); // 250 + 0 - 50.5
    });

    test('aceita valores null (tratados como 0)', () {
      final b = computeBalance(
        entries: [
          (category: 'os_payment', reversedAt: null, amount: null as Object?),
        ],
        pendingOsTotals: [null],
      );
      expect(b.recebido, 0);
      expect(b.pendente, 0);
    });

    test('categoria desconhecida não soma em lugar nenhum', () {
      final b = computeBalance(
        entries: [_entry('categoria_futura', '999.99')],
        pendingOsTotals: [],
      );
      expect(b.recebido, 0);
      expect(b.saidas, 0);
      expect(b.depositos, 0);
      expect(b.saldo, 0);
    });

    test('despesa conta como saída (não como depósito negativo)', () {
      final b = computeBalance(
        entries: [
          _entry('os_payment', '1000.00'),
          _entry('despesa', '150.00'),
          _entry('sangria', '50.00'),
        ],
        pendingOsTotals: [],
      );
      // Saídas = despesa + sangria = 200
      expect(b.saidas, 200.0);
      // Saldo = 1000 + 0 - 200 = 800
      expect(b.saldo, 800.0);
    });
  });

  group('BalanceSummary.saldo', () {
    test('positivo quando recebido + depósitos > saídas', () {
      const b = BalanceSummary(
          recebido: 1000, saidas: 200, depositos: 500, pendente: 0);
      expect(b.saldo, 1300.0);
    });

    test('negativo quando saídas > recebido + depósitos', () {
      const b = BalanceSummary(
          recebido: 100, saidas: 500, depositos: 50, pendente: 0);
      expect(b.saldo, -350.0);
    });

    test('pendente NÃO afeta o saldo', () {
      const b = BalanceSummary(
          recebido: 100, saidas: 0, depositos: 0, pendente: 99999);
      expect(b.saldo, 100.0);
    });
  });
}
