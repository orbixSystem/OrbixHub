import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// In-memory [InventoryRepository] for tests/offline. Mirrors the contract,
/// including archive-instead-of-delete and the cached stock balance updated by
/// each movement (in: +, out: -, adjust: =target).
class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository({
    InventoryConfig? config,
    List<InventoryItem>? items,
  })  : _config = config ?? const InventoryConfig(),
        _items = {for (final i in items ?? const <InventoryItem>[]) i.id: i};

  final InventoryConfig _config;
  final Map<String, InventoryItem> _items;
  final Map<String, List<InventoryMovement>> _movs = {};
  int _seq = 0;

  @override
  Future<InventoryConfig> fetchConfig() async => _config;

  @override
  Future<ItemPage> listItems({
    String? q,
    String? kind,
    String? category,
    String status = 'active',
    bool lowStock = false,
    int page = 1,
  }) async {
    final term = q?.toLowerCase();
    var list = _items.values.where((i) => status == 'all' || i.status == status);
    if (kind != null && kind.isNotEmpty) {
      list = list.where((i) => i.kind == kind);
    }
    if (category != null && category.isNotEmpty) {
      list = list.where((i) => i.category == category);
    }
    if (term != null && term.isNotEmpty) {
      list = list.where((i) => i.name.toLowerCase().contains(term));
    }
    if (lowStock) {
      list = list.where(_isLow);
    }
    final items = list.toList();
    return ItemPage(items: items, total: items.length);
  }

  @override
  Future<InventoryItem> getItem(String id) async => _items[id]!;

  @override
  Future<InventoryItem> createItem(ItemDraft d) async {
    final id = 'item-${_seq++}';
    final isService = d.kind == 'service';
    final item = InventoryItem(
      id: id,
      kind: d.kind,
      name: d.name,
      unit: d.unit,
      code: d.code,
      barcode: d.barcode,
      category: d.category,
      salePriceCents: d.salePriceCents ?? 0,
      costPriceCents: d.costPriceCents,
      trackStock: isService ? false : (d.trackStock ?? true),
      stockQty: '0',
      minQty: d.minQty?.toString(),
      durationMinutes: d.durationMinutes,
      brand: d.brand,
      status: 'active',
    );
    _items[id] = item;
    _movs[id] = [];
    return item;
  }

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft d) async {
    final cur = _items[id]!;
    final next = cur.copyWith(
      name: d.name,
      unit: d.unit,
      salePriceCents: d.salePriceCents ?? cur.salePriceCents,
    );
    _items[id] = next;
    return next;
  }

  @override
  Future<InventoryItem> archiveItem(String id) async {
    final next = _items[id]!.copyWith(status: 'archived');
    _items[id] = next;
    return next;
  }

  @override
  Future<InventoryItem> unarchiveItem(String id) async {
    final next = _items[id]!.copyWith(status: 'active');
    _items[id] = next;
    return next;
  }

  @override
  Future<List<InventoryMovement>> listMovements(String id) async =>
      _movs[id] ?? const [];

  @override
  Future<InventoryMovement> registerMovement(String id, MovementDraft d) async {
    final cur = _items[id]!;
    final balance = switch (d.type) {
      'in' => double.parse(cur.stockQty) + d.quantity,
      'out' => double.parse(cur.stockQty) - d.quantity,
      _ => d.quantity, // adjust → saldo-alvo
    };
    final m = InventoryMovement(
      id: 'mov-${_seq++}',
      type: d.type,
      quantity: d.quantity.toString(),
      balanceAfter: balance.toString(),
      reason: d.reason,
      note: d.note,
      createdAt: '2026-01-01T00:00:00Z',
    );
    _items[id] = cur.copyWith(stockQty: balance.toString());
    (_movs[id] ??= []).insert(0, m);
    return m;
  }

  @override
  Future<List<InventoryItem>> lowStock() async =>
      _items.values.where(_isLow).toList();

  bool _isLow(InventoryItem i) =>
      i.trackStock &&
      i.minQty != null &&
      double.parse(i.stockQty) <= double.parse(i.minQty!);
}
