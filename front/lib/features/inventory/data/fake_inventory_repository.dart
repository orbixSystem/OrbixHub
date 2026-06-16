import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// In-memory [InventoryRepository] for tests/offline. Mirrors the contract,
/// including archive-instead-of-delete and direct stock (no movements).
class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository({
    InventoryConfig? config,
    List<InventoryItem>? items,
  })  : _config = config ?? const InventoryConfig(),
        _items = {for (final i in items ?? const <InventoryItem>[]) i.id: i};

  final InventoryConfig _config;
  final Map<String, InventoryItem> _items;
  int _seq = 0;

  @override
  Future<InventoryConfig> fetchConfig() async => _config;

  @override
  Future<ItemPage> listItems({
    String? q,
    String? category,
    String? kind,
    String active = 'true',
    bool lowStock = false,
    int page = 1,
  }) async {
    final term = q?.toLowerCase();
    var list = _items.values.where((i) {
      if (active == 'all') return true;
      return i.isActive == (active == 'true');
    });
    if (kind != null && kind.isNotEmpty) {
      list = list.where((i) => i.kind == kind);
    }
    if (category != null && category.isNotEmpty) {
      list = list.where((i) => i.category == category);
    }
    if (term != null && term.isNotEmpty) {
      list = list.where((i) =>
          i.name.toLowerCase().contains(term) ||
          (i.sku?.toLowerCase().contains(term) ?? false) ||
          (i.barcode?.toLowerCase().contains(term) ?? false) ||
          (i.manufacturerCode?.toLowerCase().contains(term) ?? false));
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
      name: d.name,
      kind: d.kind,
      durationMinutes: isService ? d.durationMinutes : null,
      sku: d.sku,
      manufacturerCode: isService ? null : d.manufacturerCode,
      barcode: isService ? null : d.barcode,
      category: d.category,
      brand: d.brand,
      unit: d.unit,
      salePrice: d.salePrice?.toString(),
      costPrice: d.costPrice?.toString(),
      marginPct: d.marginPct?.toString(),
      currentStock: isService ? '0' : (d.currentStock ?? 0).toString(),
      minStock: isService ? null : d.minStock?.toString(),
      attributes: d.attributes ?? const <String, dynamic>{},
    );
    _items[id] = item;
    return item;
  }

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft d) async {
    final cur = _items[id]!;
    final isService = cur.kind == 'service'; // kind não é editável no PATCH
    final next = cur.copyWith(
      name: d.name,
      durationMinutes:
          isService ? (d.durationMinutes ?? cur.durationMinutes) : null,
      sku: d.sku,
      // barcode/manufacturerCode não editáveis: preserva os atuais.
      manufacturerCode: cur.manufacturerCode,
      barcode: cur.barcode,
      category: d.category,
      brand: d.brand,
      unit: d.unit,
      salePrice: d.salePrice?.toString() ?? cur.salePrice,
      costPrice: d.costPrice?.toString() ?? cur.costPrice,
      marginPct: d.marginPct?.toString() ?? cur.marginPct,
      currentStock: isService
          ? '0'
          : (d.currentStock?.toString() ?? cur.currentStock),
      minStock: isService ? null : (d.minStock?.toString() ?? cur.minStock),
      attributes: d.attributes ?? cur.attributes,
    );
    _items[id] = next;
    return next;
  }

  @override
  Future<InventoryItem> archiveItem(String id) async {
    final next = _items[id]!.copyWith(isActive: false);
    _items[id] = next;
    return next;
  }

  @override
  Future<InventoryItem> unarchiveItem(String id) async {
    final next = _items[id]!.copyWith(isActive: true);
    _items[id] = next;
    return next;
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.remove(id);
  }

  @override
  Future<LookupResult> lookup(String code) async {
    final hit = _items.values.where((i) =>
        i.barcode == code || i.sku == code || i.manufacturerCode == code);
    if (hit.isNotEmpty) {
      return LookupResult(source: 'internal', item: hit.first);
    }
    return const LookupResult(source: 'none');
  }

  @override
  Future<String> suggestSku(String name) async {
    final abbrev = _abbrev(name); // 4-letter prefix (ex.: CAFE)
    final existing = _items.values
        .map((i) => i.sku)
        .whereType<String>()
        .toSet();
    var n = 1;
    var sku = '$abbrev${n.toString().padLeft(4, '0')}';
    while (existing.contains(sku)) {
      n++;
      sku = '$abbrev${n.toString().padLeft(4, '0')}';
    }
    return sku;
  }

  /// Mapa simples de diacríticos comuns → ASCII.
  static const _diacritics = {
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
    'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N',
  };

  /// Abreviação de 4 letras do nome (sem acentos, maiúsculas), preenchida com
  /// 'X' até 4 chars; 'ITEM' quando não há letras.
  String _abbrev(String name) {
    var up = name.toUpperCase();
    _diacritics.forEach((k, v) => up = up.replaceAll(k, v));
    final letters = up.replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.isEmpty) return 'ITEM';
    final take = letters.length >= 4 ? letters.substring(0, 4) : letters;
    return take.padRight(4, 'X');
  }

  @override
  Future<List<InventoryItem>> lowStock() async =>
      _items.values.where(_isLow).toList();

  bool _isLow(InventoryItem i) {
    if (i.minStock == null) return false;
    final qty = double.tryParse(i.currentStock);
    final min = double.tryParse(i.minStock!);
    if (qty == null || min == null) return false;
    return qty <= min;
  }
}
