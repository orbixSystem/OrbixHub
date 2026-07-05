import '../domain/sale_models.dart';
import '../domain/sale_repository.dart';

/// Fake in-memory de Vendas — para dev/teste (não é persistência offline).
/// Reproduz o essencial: cria com número sequencial, nasce `a_receber`, cancela
/// logicamente, emite nota (snapshot). Pagamento real é derivado do caixa no
/// backend; aqui fica simples (a_receber até o teste mexer).
class FakeSaleRepository implements SaleRepository {
  FakeSaleRepository({List<Sale> sales = const []}) {
    _sales.addAll(sales);
  }

  final List<Sale> _sales = [];
  int _seq = 0;

  @override
  Future<SalePage> listSales({
    String? status,
    String? customerId,
    int page = 1,
  }) async {
    final filtered = _sales.where((s) {
      if (status != null && s.status != status) return false;
      if (customerId != null && s.customerId != customerId) return false;
      return true;
    }).toList(growable: false);
    return SalePage(items: filtered, total: filtered.length);
  }

  @override
  Future<Sale> getSale(String id) async =>
      _sales.firstWhere((s) => s.id == id);

  @override
  Future<Sale> createSale(SaleDraft draft) async {
    _seq++;
    final items = <SaleItem>[];
    var total = 0.0;
    for (var i = 0; i < draft.items.length; i++) {
      final d = draft.items[i];
      final price = d.unitPrice ?? 0;
      final sub = (d.quantity * price);
      total += sub;
      items.add(SaleItem(
        id: 'si-$_seq-$i',
        kind: d.kind ?? 'product',
        inventoryItemId: d.inventoryItemId,
        name: d.name ?? 'Item',
        quantity: d.quantity.toStringAsFixed(3),
        unitPrice: price.toStringAsFixed(2),
        subtotal: sub.toStringAsFixed(2),
      ));
    }
    final sale = Sale(
      id: 'sale-$_seq',
      number: 'VND-${_seq.toString().padLeft(4, '0')}',
      customerId: draft.customerId,
      status: 'active',
      total: total.toStringAsFixed(2),
      paymentStatus: 'a_receber',
      items: items,
    );
    _sales.insert(0, sale);
    return sale;
  }

  @override
  Future<Sale> cancelSale(String id, {String? reason}) async {
    final idx = _sales.indexWhere((s) => s.id == id);
    final canceled =
        _sales[idx].copyWith(status: 'canceled', paymentStatus: 'cancelada');
    _sales[idx] = canceled;
    return canceled;
  }

  @override
  Future<SaleFiscalResult> emitInvoice(String id) async {
    final idx = _sales.indexWhere((s) => s.id == id);
    _sales[idx] = _sales[idx].copyWith(fiscalStatus: 'emitida');
    return const SaleFiscalResult(status: 'emitida', externalId: 'NFe-FAKE');
  }
}
