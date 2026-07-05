import '../domain/sale_models.dart';
import '../domain/sale_repository.dart';

/// In-memory [SaleRepository] para dev/testes. Espelha o contrato: lista
/// paginada com filtro de status/cliente, detalhe com itens, checkout e
/// cancelamento (sem hard delete — só muda o status e estorna o estoque).
class FakeSaleRepository implements SaleRepository {
  FakeSaleRepository({List<Sale>? seed})
      : _sales = [...(seed ?? _defaultSeed())];

  final List<Sale> _sales;
  int _seq = 1000;

  static List<Sale> _defaultSeed() => [
        Sale(
          id: 'sale-1',
          number: '1',
          customerId: 'cli-1',
          customerName: 'Maria Oliveira',
          status: 'concluida',
          paymentMethod: 'pix',
          discount: '0.00',
          subtotal: '90.00',
          total: '90.00',
          stockApplied: true,
          createdAt: '2026-07-04T13:05:00.000Z',
          items: const [
            SaleItem(
              id: 'si-1',
              inventoryItemId: 'item-1',
              kind: 'product',
              name: 'Óleo 5W30 1L',
              quantity: '2',
              unitPrice: '45.00',
              discount: '0.00',
              total: '90.00',
            ),
          ],
        ),
        Sale(
          id: 'sale-2',
          number: '2',
          customerName: null,
          status: 'concluida',
          paymentMethod: 'dinheiro',
          discount: '5.00',
          subtotal: '35.00',
          total: '30.00',
          stockApplied: true,
          createdAt: '2026-07-04T15:40:00.000Z',
          items: const [
            SaleItem(
              id: 'si-2',
              kind: 'service',
              name: 'Calibragem de pneus',
              quantity: '1',
              unitPrice: '35.00',
              discount: '0.00',
              total: '35.00',
            ),
          ],
        ),
      ];

  @override
  Future<SalePage> list({
    int page = 1,
    String? status,
    String? customerId,
  }) async {
    final filtered = _sales.where((s) {
      final statusOk = status == null || status.isEmpty || s.status == status;
      final custOk =
          customerId == null || customerId.isEmpty || s.customerId == customerId;
      return statusOk && custOk;
    }).toList();
    return SalePage(
      items: filtered,
      total: filtered.length,
      page: page,
      pageSize: 20,
    );
  }

  @override
  Future<Sale> getOne(String id) async {
    return _sales.firstWhere(
      (s) => s.id == id,
      orElse: () => throw StateError('Venda não encontrada: $id'),
    );
  }

  @override
  Future<Sale> checkout(SaleDraft draft) async {
    num subtotal = 0;
    final items = <SaleItem>[];
    for (var i = 0; i < draft.items.length; i++) {
      final d = draft.items[i];
      subtotal += d.lineTotal;
      items.add(SaleItem(
        id: 'si-${_seq}_$i',
        inventoryItemId: d.inventoryItemId,
        kind: d.kind,
        name: d.name,
        quantity: d.quantity.toString(),
        unitPrice: d.unitPrice.toStringAsFixed(2),
        discount: (d.discount ?? 0).toStringAsFixed(2),
        total: d.lineTotal.toStringAsFixed(2),
      ));
    }
    final discount = draft.discount ?? 0;
    final total = (subtotal - discount) < 0 ? 0 : subtotal - discount;
    final created = Sale(
      id: 'sale-$_seq',
      number: '${_seq++}',
      customerId: draft.customerId,
      status: 'concluida',
      paymentMethod: draft.paymentMethod,
      discount: discount.toStringAsFixed(2),
      subtotal: subtotal.toStringAsFixed(2),
      total: total.toStringAsFixed(2),
      stockApplied: true,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      items: items,
    );
    _sales.insert(0, created);
    return created;
  }

  @override
  Future<Sale> cancel(String id, String reason) async {
    final idx = _sales.indexWhere((s) => s.id == id);
    if (idx < 0) throw StateError('Venda não encontrada: $id');
    final canceled = _sales[idx].copyWith(
      status: 'cancelada',
      stockApplied: false,
      canceledAt: DateTime.now().toUtc().toIso8601String(),
    );
    _sales[idx] = canceled;
    return canceled;
  }
}
