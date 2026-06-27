import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/cashier/data/fake_cashier_repository.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_format.dart';
import 'package:orbixhub_front/features/cashier/domain/cashier_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

Me _me({List<String> modules = const [], List<String> permissions = const []}) =>
    Me(
      user: const User(id: 'u1', email: 'me@b.c', fullName: 'Me'),
      activeTenant: const Tenant(id: 't1', slug: 's1', name: 'N1'),
      role: 'owner',
      permissions: permissions,
      modules: modules,
    );

void main() {
  group('gating de menu', () {
    test('Caixa aparece quando o módulo cashier está habilitado', () {
      final routes =
          gatedNavItems(_me(modules: ['cashier'])).map((i) => i.route);
      expect(routes, contains('/m/cashier'));
    });
    test('Caixa não aparece sem o módulo', () {
      final routes = gatedNavItems(_me(modules: ['os'])).map((i) => i.route);
      expect(routes, isNot(contains('/m/cashier')));
    });
  });

  group('helpers puros', () {
    test('direção derivada da categoria', () {
      expect(isOutflowCategory('despesa'), isTrue);
      expect(isOutflowCategory('sangria'), isTrue);
      expect(isOutflowCategory('os_payment'), isFalse);
      expect(isOutflowCategory('suprimento'), isFalse);
    });
    test('formatMoney pt-BR com milhar', () {
      expect(formatMoney(1234.5), 'R\$ 1.234,50');
      expect(formatMoney('70'), 'R\$ 70,00');
      expect(formatMoney(-5), '-R\$ 5,00');
    });
    test('rótulos PT-BR', () {
      expect(methodLabel('cartao_credito'), 'Cartão crédito');
      expect(categoryLabel('os_payment'), 'Recebimento OS');
    });
  });

  group('FakeCashierRepository', () {
    test('abre, recebe parcial em 2 formas e deriva o status da venda', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 0);
      await repo.createEntry(const EntryDraft(
          amount: 40, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: 'os1'));
      await repo.createEntry(const EntryDraft(
          amount: 30, method: 'pix', category: 'os_payment', saleKind: 'os', saleId: 'os1'));

      final pago = await repo.paymentSummary(saleKind: 'os', saleId: 'os1', total: 100);
      expect(pago.paid, 70);
      expect(pago.balance, 30);
      expect(pago.status, 'parcial');

      // quita
      await repo.createEntry(const EntryDraft(
          amount: 30, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: 'os1'));
      final quitado = await repo.paymentSummary(saleKind: 'os', saleId: 'os1', total: 100);
      expect(quitado.status, 'pago');
      expect(quitado.balance, 0);
    });

    test('estorno lógico sai dos somatórios mas não some do extrato', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 0);
      final entry = await repo.createEntry(const EntryDraft(
          amount: 50, method: 'dinheiro', category: 'suprimento'));
      expect((await repo.summary()).totalIn, 50);

      await repo.reverseEntry(entry.id, 'erro');
      expect((await repo.summary()).totalIn, 0);
      // ainda listada (não apagada)
      final page = await repo.listEntries();
      expect(page.items.length, 1);
      expect(page.items.first.reversedAt, isNotNull);
    });

    test('fechamento só-dinheiro: pix não entra no esperado', () async {
      final repo = FakeCashierRepository();
      await repo.openSession(openingAmount: 100);
      await repo.createEntry(const EntryDraft(
          amount: 50, method: 'dinheiro', category: 'suprimento'));
      await repo.createEntry(const EntryDraft(
          amount: 999, method: 'pix', category: 'suprimento'));
      final closed = await repo.closeSession(countedAmount: 150);
      expect(moneyToDouble(closed.closingAmountExpected), 150); // 100 + 50 (só dinheiro)
      expect(moneyToDouble(closed.difference), 0);
    });
  });
}
