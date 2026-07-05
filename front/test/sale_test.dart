import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/auth/domain/auth_models.dart';
import 'package:orbixhub_front/features/sale/data/fake_sale_repository.dart';
import 'package:orbixhub_front/features/sale/domain/sale_models.dart';
import 'package:orbixhub_front/features/shell/presentation/nav_items.dart';

void main() {
  group('FakeSaleRepository', () {
    test('createSale gera número VND e nasce a_receber', () async {
      final repo = FakeSaleRepository();
      final sale = await repo.createSale(
        const SaleDraft(items: [
          SaleItemDraft(name: 'Item', kind: 'service', quantity: 2, unitPrice: 10),
        ]),
      );
      expect(sale.number, 'VND-0001');
      expect(sale.paymentStatus, 'a_receber');
      expect(sale.total, '20.00');
      expect(sale.status, 'active');
    });

    test('cancelSale marca canceled (estorno lógico)', () async {
      final repo = FakeSaleRepository();
      final sale = await repo.createSale(
        const SaleDraft(items: [
          SaleItemDraft(name: 'Item', kind: 'service', quantity: 1, unitPrice: 5),
        ]),
      );
      final canceled = await repo.cancelSale(sale.id);
      expect(canceled.status, 'canceled');
      expect(canceled.paymentStatus, 'cancelada');
    });

    test('emitInvoice guarda snapshot fiscal (emitida)', () async {
      final repo = FakeSaleRepository();
      final sale = await repo.createSale(
        const SaleDraft(items: [
          SaleItemDraft(name: 'X', kind: 'service', quantity: 1, unitPrice: 5),
        ]),
      );
      final res = await repo.emitInvoice(sale.id);
      expect(res.status, 'emitida');
      expect((await repo.getSale(sale.id)).fiscalStatus, 'emitida');
    });
  });

  group('navegação', () {
    // Venda avulsa é AÇÃO no Caixa — `sale` nunca vira item de menu, mesmo com o
    // entitlement habilitado (não vazar estrutura interna pro usuário).
    test('sale NÃO aparece no menu mesmo com o módulo habilitado', () {
      const me = Me(
        user: User(id: 'u1', email: 'a@b.c', fullName: 'A'),
        role: 'caixa',
        permissions: ['sale.read', 'sale.write', 'cashier.read'],
        modules: ['cashier', 'sale'],
      );
      final items = gatedNavItems(me);
      expect(items.any((i) => i.route == '/m/sale'), isFalse);
      expect(items.any((i) => i.label.toLowerCase() == 'sale'), isFalse);
      expect(items.any((i) => i.label == 'Vendas'), isFalse);
      // o Caixa, sim, aparece (é onde a venda avulsa vive).
      expect(items.any((i) => i.route == '/m/cashier'), isTrue);
    });
  });
}
