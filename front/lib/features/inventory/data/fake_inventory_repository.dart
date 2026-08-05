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

  /// Tamanho do lote — espelha o DEFAULT_PAGE_SIZE do backend (20).
  static const _pageSize = 20;

  @override
  Future<ItemPage> listItems({
    String? q,
    String? category,
    String? kind,
    String active = 'true',
    bool lowStock = false,
    String sort = 'name_asc',
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
    final all = list.toList()..sort(_comparatorFor(sort));
    final total = all.length;
    // Paginação por skip/take (mesma semântica do backend).
    final skip = (page - 1) * _pageSize;
    final items =
        skip >= total ? <InventoryItem>[] : all.skip(skip).take(_pageSize).toList();
    return ItemPage(items: items, total: total, page: page, pageSize: _pageSize);
  }

  /// Comparador espelhando o ITEM_ORDER_BY do backend, com `id` como desempate
  /// final (paginação estável). Preço nulo vai para o fim em ambas direções.
  int Function(InventoryItem, InventoryItem) _comparatorFor(String sort) {
    double? price(InventoryItem i) =>
        i.salePrice == null ? null : double.tryParse(i.salePrice!);
    double stock(InventoryItem i) => double.tryParse(i.currentStock) ?? 0;
    int byId(InventoryItem a, InventoryItem b) => a.id.compareTo(b.id);
    int priceCmp(InventoryItem a, InventoryItem b, {required bool desc}) {
      final pa = price(a), pb = price(b);
      if (pa == null && pb == null) return 0;
      if (pa == null) return 1; // nulls last
      if (pb == null) return -1;
      return desc ? pb.compareTo(pa) : pa.compareTo(pb);
    }

    int Function(InventoryItem, InventoryItem) primary;
    switch (sort) {
      case 'name_desc':
        primary = (a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase());
      case 'price_desc':
        primary = (a, b) => priceCmp(a, b, desc: true);
      case 'price_asc':
        primary = (a, b) => priceCmp(a, b, desc: false);
      case 'stock_desc':
        primary = (a, b) => stock(b).compareTo(stock(a));
      case 'stock_asc':
        primary = (a, b) => stock(a).compareTo(stock(b));
      case 'recent':
        // Sem created_at no fake: aproxima por id decrescente (ordem de criação).
        primary = (a, b) => b.id.compareTo(a.id);
      case 'name_asc':
      default:
        primary = (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    return (a, b) {
      final p = primary(a, b);
      return p != 0 ? p : byId(a, b);
    };
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
      description: d.description,
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
      description: d.description ?? cur.description,
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
