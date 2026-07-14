import '../../../core/offline/local_first.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// [InventoryRepository] offline-first (B8) — decorator sobre a impl real (dio).
/// Mesmo padrão do módulo Clientes (ver [LocalFirstBase]).
///
/// Entidade espelhada: `inventory_item`.
///
/// Offline lançam "Requer conexão": `lookup(code)` **quando o código não está no
/// estoque local** (aí só o catálogo externo responderia).
class LocalFirstInventoryRepository extends LocalFirstBase
    implements InventoryRepository {
  LocalFirstInventoryRepository({
    required this.inner,
    required super.db,
    required super.clock,
    required super.isOnline,
    required super.currentUserId,
    super.onWrite,
  });

  final InventoryRepository inner;

  static const _entity = 'inventory_item';
  static const _pageSize = 20;

  // ============================ config ==================================

  @override
  Future<InventoryConfig> fetchConfig() async {
    if (isOnline()) {
      final config = await inner.fetchConfig();
      await putRow(LocalConfigEntities.inventory, {
        'id': LocalConfigEntities.rowId,
        ...config.toJson(),
      });
      return config;
    }
    final cached = await rowById(
      LocalConfigEntities.inventory,
      LocalConfigEntities.rowId,
    );
    if (cached == null) return const InventoryConfig();
    return InventoryConfig.fromJson(cached);
  }

  // ============================= leitura ================================

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
    if (isOnline()) {
      final res = await inner.listItems(
        q: q,
        category: category,
        kind: kind,
        active: active,
        lowStock: lowStock,
        sort: sort,
        page: page,
      );
      await putRows(_entity, [for (final i in res.items) i.toJson()]);
      return res;
    }

    final filtered = (await rows(_entity)).where((row) {
      if (active != 'all') {
        final isActive = row['is_active'] as bool? ?? true;
        if (isActive != (active == 'true')) return false;
      }
      if (category != null && category.isNotEmpty && row['category'] != category) {
        return false;
      }
      if (kind != null && kind.isNotEmpty && (row['kind'] ?? 'product') != kind) {
        return false;
      }
      if (lowStock && !_isLowStock(row)) return false;
      if (q == null || q.isEmpty) return true;
      return matches(row['name'] as String?, q) ||
          matches(row['sku'] as String?, q) ||
          matches(row['barcode'] as String?, q) ||
          matches(row['manufacturer_code'] as String?, q) ||
          matches(row['brand'] as String?, q);
    }).toList();

    _sortItems(filtered, sort);

    return ItemPage(
      items: [
        for (final row in pageOf(filtered, page, _pageSize))
          InventoryItem.fromJson(row),
      ],
      total: filtered.length,
      page: page,
      pageSize: _pageSize,
    );
  }

  bool _isLowStock(Map<String, dynamic> row) {
    final min = row['min_stock'];
    if (min == null) return false;
    return toNum(row['current_stock']) <= toNum(min);
  }

  void _sortItems(List<Map<String, dynamic>> items, String sort) {
    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        ((a['name'] ?? '') as String)
            .toLowerCase()
            .compareTo(((b['name'] ?? '') as String).toLowerCase());
    items.sort((a, b) {
      switch (sort) {
        case 'name_desc':
          return byName(b, a);
        case 'price_desc':
          return toNum(b['sale_price']).compareTo(toNum(a['sale_price']));
        case 'price_asc':
          return toNum(a['sale_price']).compareTo(toNum(b['sale_price']));
        case 'stock_desc':
          return toNum(b['current_stock']).compareTo(toNum(a['current_stock']));
        case 'stock_asc':
          return toNum(a['current_stock']).compareTo(toNum(b['current_stock']));
        case 'recent':
          return ((b['created_at'] ?? '') as String)
              .compareTo((a['created_at'] ?? '') as String);
        case 'name_asc':
        default:
          return byName(a, b);
      }
    });
  }

  @override
  Future<InventoryItem> getItem(String id) async {
    if (isOnline()) {
      final item = await inner.getItem(id);
      await putRow(_entity, item.toJson());
      return item;
    }
    final row = await rowById(_entity, id);
    if (row == null) notFoundLocally('Produto');
    return InventoryItem.fromJson(row);
  }

  @override
  Future<List<InventoryItem>> lowStock() async {
    if (isOnline()) {
      final items = await inner.lowStock();
      await putRows(_entity, [for (final i in items) i.toJson()]);
      return items;
    }
    final low = (await rows(_entity))
        .where((row) => (row['is_active'] as bool? ?? true) && _isLowStock(row))
        .toList();
    _sortItems(low, 'name_asc');
    return [for (final row in low) InventoryItem.fromJson(row)];
  }

  // ============================= escrita ================================

  @override
  Future<InventoryItem> createItem(ItemDraft draft) async {
    if (isOnline()) {
      final item = await inner.createItem(draft);
      await putRow(_entity, item.toJson());
      return item;
    }
    final id = newId();
    await enqueue(_entity, 'create', {'id': id, ...draft.toJson()});
    final row = _rowFromDraft({'id': id, 'is_active': true}, draft);
    await putRow(_entity, row);
    return InventoryItem.fromJson(row);
  }

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft draft) async {
    if (isOnline()) {
      final item = await inner.updateItem(id, draft);
      await putRow(_entity, item.toJson());
      return item;
    }
    final row = await rowById(_entity, id);
    if (row == null) notFoundLocally('Produto');
    await enqueue(_entity, 'update', {'id': id, ...draft.toJson()});
    final merged = _rowFromDraft(row, draft);
    await putRow(_entity, merged);
    return InventoryItem.fromJson(merged);
  }

  /// Aplica um [ItemDraft] (camelCase, números) sobre uma linha do row-store
  /// (snake_case, decimais como String) — a mesma tradução que o backend faz.
  Map<String, dynamic> _rowFromDraft(
    Map<String, dynamic> base,
    ItemDraft draft,
  ) {
    return {
      ...base,
      'name': draft.name,
      'kind': draft.kind,
      if (draft.durationMinutes != null)
        'duration_minutes': draft.durationMinutes,
      if (draft.sku != null) 'sku': draft.sku,
      if (draft.manufacturerCode != null)
        'manufacturer_code': draft.manufacturerCode,
      if (draft.barcode != null) 'barcode': draft.barcode,
      if (draft.category != null) 'category': draft.category,
      if (draft.brand != null) 'brand': draft.brand,
      if (draft.unit != null) 'unit': draft.unit,
      if (draft.salePrice != null) 'sale_price': dec(draft.salePrice),
      if (draft.costPrice != null) 'cost_price': dec(draft.costPrice),
      if (draft.marginPct != null) 'margin_pct': dec(draft.marginPct),
      'current_stock':
          dec(draft.currentStock) ?? (base['current_stock'] ?? '0'),
      if (draft.minStock != null) 'min_stock': dec(draft.minStock),
      if (draft.attributes != null) 'attributes': draft.attributes,
      'created_at': base['created_at'] ?? nowIso(),
      'updated_at': nowIso(),
    };
  }

  @override
  Future<InventoryItem> archiveItem(String id) =>
      _flagActive(id, 'archive', false, inner.archiveItem);

  @override
  Future<InventoryItem> unarchiveItem(String id) =>
      _flagActive(id, 'unarchive', true, inner.unarchiveItem);

  Future<InventoryItem> _flagActive(
    String id,
    String op,
    bool isActive,
    Future<InventoryItem> Function(String id) online,
  ) async {
    if (isOnline()) {
      final item = await online(id);
      await putRow(_entity, item.toJson());
      return item;
    }
    final row = await rowById(_entity, id);
    if (row == null) notFoundLocally('Produto');
    final merged = {...row, 'is_active': isActive, 'updated_at': nowIso()};
    await putRow(_entity, merged);
    await enqueue(_entity, op, {'id': id});
    return InventoryItem.fromJson(merged);
  }

  /// Soft delete no backend (some das listas) — localmente a linha sai do espelho.
  @override
  Future<void> deleteItem(String id) async {
    if (isOnline()) {
      await inner.deleteItem(id);
      await removeRow(_entity, id);
      return;
    }
    await enqueue(_entity, 'delete', {'id': id});
    await removeRow(_entity, id);
  }

  // ======================== código-first / sku ==========================

  /// Offline resolvemos pelo ESTOQUE LOCAL (barras/fabricante/sku). Sem match, o
  /// que restaria é o catálogo externo — que exige conexão.
  @override
  Future<LookupResult> lookup(String code) async {
    if (isOnline()) {
      final res = await inner.lookup(code);
      final item = res.item;
      if (item != null) await putRow(_entity, item.toJson());
      return res;
    }
    final needle = code.trim().toLowerCase();
    for (final row in await rows(_entity)) {
      final hit = [row['barcode'], row['manufacturer_code'], row['sku']]
          .whereType<String>()
          .any((v) => v.toLowerCase() == needle);
      if (hit) {
        return LookupResult(source: 'internal', item: InventoryItem.fromJson(row));
      }
    }
    requiresConnection('consultar o catálogo externo deste código');
  }

  /// Offline geramos o SKU localmente (mesma ideia do backend: base do nome +
  /// sufixo até ficar único entre os itens espelhados).
  @override
  Future<String> suggestSku(String name) async {
    if (isOnline()) return inner.suggestSku(name);
    final base = name
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final prefix = (base.isEmpty ? 'ITEM' : base);
    final taken = {
      for (final row in await rows(_entity))
        if (row['sku'] is String) (row['sku'] as String).toUpperCase(),
    };
    if (!taken.contains(prefix)) return prefix;
    for (var i = 2;; i++) {
      final candidate = '$prefix-$i';
      if (!taken.contains(candidate)) return candidate;
    }
  }
}
