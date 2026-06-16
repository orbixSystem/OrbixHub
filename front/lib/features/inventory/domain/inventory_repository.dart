import 'inventory_models.dart';

/// Contrato do módulo Estoque (produtos). O backend é a verdade (RLS +
/// permissões + gating de módulo); o cliente só reflete para UX. Impl real (dio)
/// + fake, trocadas por injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class InventoryRepository {
  // ---- config (campos dinâmicos da vertical) ----
  Future<InventoryConfig> fetchConfig();

  // ---- items ----
  Future<ItemPage> listItems({
    String? q,
    String? category,
    String active,
    bool lowStock,
    int page,
  });
  Future<InventoryItem> getItem(String id);
  Future<InventoryItem> createItem(ItemDraft draft);
  Future<InventoryItem> updateItem(String id, ItemDraft draft);
  Future<InventoryItem> archiveItem(String id);
  Future<InventoryItem> unarchiveItem(String id);

  /// Soft delete: sai da lista, preservado no sistema (`DELETE /inventory/items/:id`).
  Future<void> deleteItem(String id);

  /// Código-first: resolve por barras/fabricante/sku (`GET /inventory/lookup`).
  Future<LookupResult> lookup(String code);

  /// Sugere um SKU único para o tenant a partir do nome
  /// (`GET /inventory/sku-suggestion?name=`).
  Future<String> suggestSku(String name);

  /// Itens com saldo no/abaixo do mínimo (filtro `lowStock=true`).
  Future<List<InventoryItem>> lowStock();
}
