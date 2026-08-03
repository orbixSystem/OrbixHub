import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_format.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';

/// Abrir e fechar o caixa eram operações às cegas: a abertura começava em zero
/// (obrigando a redigitar o troco todo dia) e o fechamento pedia o valor contado
/// SEM mostrar o esperado — apesar de o texto prometer "calculamos o esperado" e
/// de o dado já chegar em `currentSession`.
void main() {
  group('cashDifference', () {
    test('sobra é positiva', () {
      expect(cashDifference(counted: 150, expected: 100), 50);
    });

    test('falta é negativa', () {
      expect(cashDifference(counted: 80, expected: 100), -20);
    });

    test('confere = zero', () {
      expect(cashDifference(counted: 100, expected: 100), 0);
    });

    test('arredonda para centavos (evita lixo de ponto flutuante)', () {
      // Sem o arredondamento, estas subtrações vazam representação binária:
      // 0.1 + 0.2 − 0.3 não dá zero, e 100.10 − 100 dá 0.09999999999999432.
      expect(cashDifference(counted: 0.3, expected: 0.1 + 0.2), 0);
      expect(cashDifference(counted: 100.10, expected: 100), 0.10);
      expect(cashDifference(counted: 1000.03, expected: 999.99), 0.04);
    });
  });

  group('cashDifferenceLabel', () {
    test('sem diferença', () {
      expect(cashDifferenceLabel(0), contains('certinho'));
    });

    test('sobra', () {
      final l = cashDifferenceLabel(50);
      expect(l, contains('SOBRA'));
      expect(l, contains('50,00'));
    });

    test('falta mostra o valor absoluto (nunca "-R\$")', () {
      final l = cashDifferenceLabel(-20);
      expect(l, contains('FALTA'));
      expect(l, contains('20,00'));
      expect(l, isNot(contains('-R\$')));
    });
  });

  group('formatAmountForInput', () {
    test('usa vírgula e não põe R\$ nem separador de milhar', () {
      // Precisa ser aceito pelo DecimalInputFormatter e pelo parse do caixa.
      expect(formatAmountForInput(1234.5), '1234,50');
      expect(formatAmountForInput(0), '0,00');
      expect(formatAmountForInput(87.9), '87,90');
    });

    test('o texto produzido é reparseável', () {
      final t = formatAmountForInput(1234.56);
      expect(double.tryParse(t.replaceAll(',', '.')), 1234.56);
    });
  });

  group('sugestão de abertura (lastClosingAmount)', () {
    test('sem fechamento anterior não sugere nada', () async {
      final repo = FakeCashierRepository();
      expect(await repo.lastClosingAmount(), isNull);
    });

    test('sugere o valor contado no último fechamento', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 100);
      await repo.closeSession(countedAmount: 87.9);
      expect(await repo.lastClosingAmount(), 87.9);
    });

    test('usa o fechamento MAIS RECENTE quando há vários', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 100);
      await repo.closeSession(countedAmount: 50);
      await repo.openSession(openingAmount: 50);
      await repo.closeSession(countedAmount: 210.25);
      expect(await repo.lastClosingAmount(), 210.25);
    });

    test('o valor sugerido volta formatado para o campo', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 0);
      await repo.closeSession(countedAmount: 1234.5);
      final sugerido = await repo.lastClosingAmount();
      expect(formatAmountForInput(sugerido!), '1234,50');
    });
  });

  group('fechamento calcula esperado e diferença', () {
    test('esperado = abertura + entradas − saídas; diferença vem do contado',
        () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 100);
      await repo.createEntry(const EntryDraft(
        amount: 60,
        method: 'dinheiro',
        category: 'venda_avulsa',
      ));
      await repo.createEntry(const EntryDraft(
        amount: 25,
        method: 'dinheiro',
        category: 'despesa',
      ));

      // Antes de fechar, a tela já consegue mostrar o esperado.
      final aberta = await repo.currentSession();
      expect(aberta!.totals!.expected, 135); // 100 + 60 − 25

      final fechada = await repo.closeSession(countedAmount: 130);
      expect(moneyToDouble(fechada.closingAmountExpected), 135);
      expect(moneyToDouble(fechada.difference), -5);
      expect(cashDifferenceLabel(moneyToDouble(fechada.difference)),
          contains('FALTA'));
    });

    test('histórico guarda a sessão fechada (antes era descartada)', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 10);
      await repo.closeSession(countedAmount: 10);
      final page = await repo.listSessions();
      expect(page.items, hasLength(1));
      expect(page.items.first.status, 'closed');
    });
  });
}
