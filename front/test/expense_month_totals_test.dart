import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_month_totals.dart';

/// Totais do mês derivados no cliente (para o modo offline).
///
/// Online o servidor soma; offline somamos aqui. Total errado numa tela de contas
/// a pagar leva a decisão errada sobre dinheiro, então cada regra tem teste.
void main() {
  final hoje = DateTime(2026, 8, 15);

  Expense conta(
    String desc, {
    required String venc,
    num valor = 100,
    String? pagoEm,
    num? valorPago,
  }) =>
      Expense(
        id: desc,
        description: desc,
        amount: valor,
        dueDate: '${venc}T00:00:00.000Z',
        paidAt: pagoEm == null ? null : '${pagoEm}T12:00:00.000Z',
        paidAmount: valorPago,
      );

  group('totaisDoMes', () {
    test('previsto soma TODAS as contas, pagas ou não', () {
      final m = totaisDoMes(
        contas: [
          conta('a', venc: '2026-08-10', valor: 100, pagoEm: '2026-08-10'),
          conta('b', venc: '2026-08-20', valor: 250),
        ],
        categorias: const [],
        hoje: hoje,
      );
      // É o peso do mês, não o que falta.
      expect(m.totalPrevisto, 350);
    });

    test('pago usa o valor REALMENTE pago (juros/desconto divergem)', () {
      final m = totaisDoMes(
        contas: [
          // Pagou com juros: saiu mais do que o previsto.
          conta('luz', venc: '2026-08-05', valor: 200, pagoEm: '2026-08-09', valorPago: 218.40),
        ],
        categorias: const [],
        hoje: hoje,
      );
      expect(m.totalPrevisto, 200);
      expect(m.totalPago, 218.40);
    });

    test('baixa sem paid_amount cai no previsto (não soma zero)', () {
      // Baixa antiga pode não ter gravado o valor; somar zero faria o mês
      // parecer não pago.
      final m = totaisDoMes(
        contas: [conta('x', venc: '2026-08-05', valor: 90, pagoEm: '2026-08-05')],
        categorias: const [],
        hoje: hoje,
      );
      expect(m.totalPago, 90);
    });

    test('em aberto é só o não pago', () {
      final m = totaisDoMes(
        contas: [
          conta('paga', venc: '2026-08-05', valor: 100, pagoEm: '2026-08-05'),
          conta('aberta', venc: '2026-08-25', valor: 300),
        ],
        categorias: const [],
        hoje: hoje,
      );
      expect(m.totalEmAberto, 300);
    });

    test('vencido é SUBCONJUNTO do em aberto, não uma quarta fatia', () {
      final m = totaisDoMes(
        contas: [
          conta('atrasada', venc: '2026-08-10', valor: 120),
          conta('futura', venc: '2026-08-28', valor: 80),
        ],
        categorias: const [],
        hoje: hoje,
      );
      expect(m.totalEmAberto, 200);
      expect(m.totalVencido, 120);
      // Somar vencido + emAberto daria 320 e mostraria dívida que não existe.
      expect(m.totalVencido, lessThanOrEqualTo(m.totalEmAberto));
    });

    test('conta paga em atraso NÃO entra em vencido', () {
      final m = totaisDoMes(
        contas: [
          conta('paga-atrasada', venc: '2026-08-02', valor: 150, pagoEm: '2026-08-14'),
        ],
        categorias: const [],
        hoje: hoje,
      );
      expect(m.totalVencido, 0);
      expect(m.totalEmAberto, 0);
      expect(m.totalPago, 150);
    });

    test('mês vazio devolve zeros, não nulos', () {
      final m = totaisDoMes(contas: const [], categorias: const [], hoje: hoje);
      expect(m.totalPrevisto, 0);
      expect(m.totalPago, 0);
      expect(m.totalEmAberto, 0);
      expect(m.totalVencido, 0);
      expect(m.items, isEmpty);
    });

    test('devolve itens e categorias recebidos (a tela precisa dos dois)', () {
      const cats = [ExpenseCategory(id: 'c1', name: 'Energia')];
      final m = totaisDoMes(
        contas: [conta('a', venc: '2026-08-10')],
        categorias: cats,
        hoje: hoje,
      );
      expect(m.items.length, 1);
      expect(m.categories, cats);
    });
  });

  group('contasDoMes', () {
    test('recorta pelo mês do VENCIMENTO', () {
      final todas = [
        conta('julho', venc: '2026-07-31'),
        conta('agosto-1', venc: '2026-08-01'),
        conta('agosto-31', venc: '2026-08-31'),
        conta('setembro', venc: '2026-09-01'),
      ];
      final agosto = contasDoMes(todas, ano: 2026, mes: 8);
      expect(
        agosto.map((e) => e.description),
        ['agosto-1', 'agosto-31'],
      );
    });

    test('data inválida é descartada em vez de derrubar a lista', () {
      final todas = [
        const Expense(id: 'x', description: 'podre', dueDate: 'nao-e-data'),
        conta('ok', venc: '2026-08-10'),
      ];
      expect(contasDoMes(todas, ano: 2026, mes: 8).length, 1);
    });

    test('mês sem contas devolve vazio', () {
      final todas = [conta('agosto', venc: '2026-08-10')];
      expect(contasDoMes(todas, ano: 2026, mes: 12), isEmpty);
    });
  });
}
