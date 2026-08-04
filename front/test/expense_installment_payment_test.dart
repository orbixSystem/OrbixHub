import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_installment_payment.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_models.dart';
import 'package:orbixhub_front/features/expenses/domain/expense_month_totals.dart';

/// Pagar parcelas em bloco: quais e quanto.
///
/// Escolher a parcela errada deixa a compra com um buraco no meio (a 4ª paga e a
/// 2ª aberta) e o cliente descobre pelo telefonema do fornecedor. Por isso a
/// seleção é função pura e testada, não um laço dentro do diálogo.
void main() {
  Expense p(int n, {bool pago = false, num valor = 100, String venc = '2026-08-10'}) =>
      Expense(
        id: 'p$n',
        description: 'Compressor',
        amount: valor,
        dueDate: '${venc}T00:00:00.000Z',
        installmentNo: n,
        installmentTotal: 6,
        installmentGroupId: 'g',
        paidAt: pago ? '2026-08-01T12:00:00.000Z' : null,
      );

  List<int> numeros(List<Expense> l) => l.map((e) => e.installmentNo!).toList();

  group('parcelasParaPagar', () {
    final grupo = [
      p(1, pago: true),
      p(2),
      p(3),
      p(4),
      p(5),
      p(6),
    ];

    test('sem quantidade, quita TODAS as abertas a partir desta', () {
      final r = parcelasParaPagar(grupo, aPartirDe: grupo[1]);
      expect(numeros(r), [2, 3, 4, 5, 6]);
    });

    test('com quantidade, pega só as N seguintes', () {
      final r = parcelasParaPagar(grupo, aPartirDe: grupo[1], quantidade: 2);
      expect(numeros(r), [2, 3]);
    });

    test('NUNCA volta para trás: antecipar não é pagar o atrasado', () {
      // A 2ª está aberta, mas quem abriu a 4ª pedindo "pagar 2" quer a 4ª e a 5ª.
      // Pagar a 2ª por conta própria mexeria em dinheiro que ninguém mandou.
      final r = parcelasParaPagar(grupo, aPartirDe: grupo[3], quantidade: 2);
      expect(numeros(r), [4, 5]);
    });

    test('pula as já pagas sem gastar a cota', () {
      final comPagaNoMeio = [p(1), p(2, pago: true), p(3), p(4)];
      // "Pagar 2" a partir da 1ª: a 2ª já está paga, então resolve a 1ª e a 3ª —
      // duas AINDA ABERTAS, que é o que a pessoa pediu.
      final r = parcelasParaPagar(
        comPagaNoMeio,
        aPartirDe: comPagaNoMeio[0],
        quantidade: 2,
      );
      expect(numeros(r), [1, 3]);
    });

    test('pedir mais do que resta devolve só o que resta', () {
      final r = parcelasParaPagar(grupo, aPartirDe: grupo[4], quantidade: 10);
      expect(numeros(r), [5, 6]);
    });

    test('quantidade zero ou negativa não paga nada', () {
      expect(parcelasParaPagar(grupo, aPartirDe: grupo[1], quantidade: 0), isEmpty);
      expect(parcelasParaPagar(grupo, aPartirDe: grupo[1], quantidade: -1), isEmpty);
    });

    test('grupo todo pago devolve vazio', () {
      final todas = [p(1, pago: true), p(2, pago: true)];
      expect(parcelasParaPagar(todas, aPartirDe: todas[0]), isEmpty);
    });

    test('ordena por NÚMERO, não por vencimento', () {
      // Vencimento corrigido à mão não deve reordenar a dívida: o número é a
      // identidade da parcela.
      final desordenado = [
        p(3, venc: '2026-08-01'),
        p(2, venc: '2026-12-01'),
      ];
      final r = parcelasParaPagar(desordenado, aPartirDe: desordenado[1]);
      expect(numeros(r), [2, 3]);
    });

    test('conta NÃO parcelada devolve ela mesma quando aberta', () {
      const avulsa = Expense(
        id: 'a',
        description: 'Aluguel',
        amount: 2500,
        dueDate: '2026-08-10T00:00:00.000Z',
      );
      expect(parcelasParaPagar(const [], aPartirDe: avulsa), [avulsa]);
    });

    test('conta NÃO parcelada já paga não devolve nada', () {
      const paga = Expense(
        id: 'a',
        description: 'Aluguel',
        amount: 2500,
        dueDate: '2026-08-10T00:00:00.000Z',
        paidAt: '2026-08-10T12:00:00.000Z',
      );
      expect(parcelasParaPagar(const [], aPartirDe: paga), isEmpty);
    });
  });

  group('totalDasParcelas', () {
    test('soma o previsto das escolhidas', () {
      expect(totalDasParcelas([p(1, valor: 33.34), p(2, valor: 33.33)]), 66.67);
    });

    test('lista vazia soma zero', () {
      expect(totalDasParcelas(const []), 0);
    });
  });

  group('resumoDosGrupos', () {
    test('total é a SOMA das irmãs, incluindo as de outros meses', () {
      // O card do mês vê uma parcela; o total da compra envolve as seis.
      final r = resumoDosGrupos(
        [p(1, pago: true, valor: 150), p(2, valor: 150), p(3, valor: 150)],
        grupos: {'g'},
      );
      expect(r.single.total, 450);
      expect(r.single.count, 3);
      expect(r.single.paidCount, 1);
    });

    test('ignora grupos que o mês não citou', () {
      final outro = p(1).copyWith(installmentGroupId: 'outro');
      final r = resumoDosGrupos([p(1), outro], grupos: {'g'});
      expect(r.single.groupId, 'g');
      expect(r.single.count, 1);
    });

    test('sem grupos pedidos devolve vazio (não varre a lista)', () {
      expect(resumoDosGrupos([p(1)], grupos: const {}), isEmpty);
    });
  });
}
