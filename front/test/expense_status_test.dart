import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_status.dart';

/// A situação de uma despesa é DERIVADA (paid_at + due_date + hoje), nunca
/// gravada. Estes testes fixam "hoje" para que o resultado não dependa do dia em
/// que a suíte roda — um teste que passa em 10/09 e falha em 11/09 é pior que
/// não ter teste.
void main() {
  final hoje = DateTime(2026, 9, 10);

  ExpenseStatus s(DateTime venc, {DateTime? pago}) =>
      statusDaDespesa(dueDate: venc, paidAt: pago, hoje: hoje);

  group('statusDaDespesa', () {
    test('vencimento no futuro distante é "a pagar"', () {
      expect(s(DateTime(2026, 9, 30)), ExpenseStatus.aPagar);
    });

    test('vencimento hoje é "vence hoje", não vencido', () {
      expect(s(DateTime(2026, 9, 10)), ExpenseStatus.venceHoje);
    });

    test('ontem já é vencido', () {
      expect(s(DateTime(2026, 9, 9)), ExpenseStatus.vencido);
    });

    test('dentro da janela de 3 dias é "vence em breve"', () {
      expect(s(DateTime(2026, 9, 11)), ExpenseStatus.venceEmBreve);
      expect(s(DateTime(2026, 9, 13)), ExpenseStatus.venceEmBreve);
    });

    test('o 4º dia já sai da janela de atenção', () {
      expect(s(DateTime(2026, 9, 14)), ExpenseStatus.aPagar);
    });

    test('paga vence qualquer outra leitura — inclusive paga em atraso', () {
      // Regra de produto: conta paga com atraso é RESOLVIDA, não "vencida".
      // Mostrá-la em vermelho faria a cliente pagar de novo.
      expect(
        s(DateTime(2026, 8, 1), pago: DateTime(2026, 8, 20)),
        ExpenseStatus.pago,
      );
    });

    test('a hora do dia não muda o resultado (compara por dia civil)', () {
      // due_date é data, não instante. Comparar com DateTime.now() cru faria a
      // conta que vence hoje virar "vencida" logo após a meia-noite.
      final status = statusDaDespesa(
        dueDate: DateTime(2026, 9, 10),
        hoje: DateTime(2026, 9, 10, 23, 59, 59),
      );
      expect(status, ExpenseStatus.venceHoje);
    });
  });

  group('diasAte', () {
    test('conta dias civis, positivo à frente e negativo em atraso', () {
      expect(diasAte(DateTime(2026, 9, 13), hoje), 3);
      expect(diasAte(DateTime(2026, 9, 10), hoje), 0);
      expect(diasAte(DateTime(2026, 9, 4), hoje), -6);
    });
  });

  group('Expense', () {
    Expense conta({num valor = 0, String? pagoEm, num? valorPago}) => Expense(
          id: 'x',
          description: 'Conta de luz',
          amount: valor,
          dueDate: '2026-09-10',
          paidAt: pagoEm,
          paidAmount: valorPago,
        );

    test('valor 0 significa "a confirmar", não "não devo nada"', () {
      expect(conta().temValor, isFalse);
      expect(conta(valor: 149.9).temValor, isTrue);
    });

    test('valor efetivo usa o pago quando ele diverge do previsto', () {
      // Juros/desconto: o que saiu é o que saiu.
      expect(conta(valor: 100, pagoEm: '2026-09-11T10:00:00Z', valorPago: 112.5)
          .valorEfetivo, 112.5);
      // Sem divergência, cai no previsto.
      expect(conta(valor: 100).valorEfetivo, 100);
    });

    test('situacao delega para a regra pura', () {
      expect(conta().situacao(hoje), ExpenseStatus.venceHoje);
      expect(
        conta(pagoEm: '2026-09-02T12:00:00Z').situacao(hoje),
        ExpenseStatus.pago,
      );
    });
  });
}
