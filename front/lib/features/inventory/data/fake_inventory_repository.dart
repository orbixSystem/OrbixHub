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
    String active = 'true',
    bool lowStock = false,
    int page = 1,
  }) async {
    final term = q?.toLowerCase();
    var list = _items.values.where((i) {
      if (active == 'all') return true;
      return i.isActive == (active == 'true');
    });
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
    final item = InventoryItem(
      id: id,
      name: d.name,
      sku: d.sku,
      manufacturerCode: d.manufacturerCode,
      barcode: d.barcode,
      category: d.category,
      brand: d.brand,
      unit: d.unit,
      salePrice: d.salePrice?.toString(),
      costPrice: d.costPrice?.toString(),
      marginPct: d.marginPct?.toString(),
      currentStock: (d.currentStock ?? 0).toString(),
      minStock: d.minStock?.toString(),
      attributes: d.attributes ?? const <String, dynamic>{},
    );
    _items[id] = item;
    return item;
  }

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft d) async {
    final cur = _items[id]!;
    final next = cur.copyWith(
      name: d.name,
      sku: d.sku,
      manufacturerCode: d.manufacturerCode,
      barcode: d.barcode,
      category: d.category,
      brand: d.brand,
      unit: d.unit,
      salePrice: d.salePrice?.toString() ?? cur.salePrice,
      costPrice: d.costPrice?.toString() ?? cur.costPrice,
      marginPct: d.marginPct?.toString() ?? cur.marginPct,
      currentStock: d.currentStock?.toString() ?? cur.currentStock,
      minStock: d.minStock?.toString() ?? cur.minStock,
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
    final base = _slug(name);
    final existing = _items.values
        .map((i) => i.sku)
        .whereType<String>()
        .toSet();
    if (!existing.contains(base)) return base;
    var n = 2;
    while (existing.contains('$base-$n')) {
      n++;
    }
    return '$base-$n';
  }

  /// Stopwords em PT-BR descartadas ao montar o slug do SKU.
  static const _stopwords = {
    'DE', 'DA', 'DO', 'DAS', 'DOS', 'E', 'COM', 'PARA', 'P', 'EM',
    'NO', 'NA', 'O', 'A', 'OS', 'AS', 'UM', 'UMA',
  };

  /// Mapa simples de diacríticos comuns → ASCII.
  static const _diacritics = {
    'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
    'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N',
  };

  String _slug(String name) {
    var up = name.toUpperCase();
    _diacritics.forEach((k, v) => up = up.replaceAll(k, v));
    final cleaned = up.replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ');
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopwords.contains(t))
        .take(3)
        .toList();
    if (tokens.isEmpty) return 'ITEM';
    var slug = tokens.join('-');
    if (slug.length > 24) slug = slug.substring(0, 24);
    return slug;
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
