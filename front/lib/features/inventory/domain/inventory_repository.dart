import 'inventory_models.dart';

/// Contrato do módulo Estoque & Serviços. O backend é a verdade (RLS +
/// permissões + gating de módulo); o cliente só reflete para UX. Impl real (dio)
/// + fake, trocadas por injeção Riverpod. A UI nunca fala com o dio direto.
abstract interface class InventoryRepository {
  // ---- config (unidade/categorias/margem padrão) ----
  Future<InventoryConfig> fetchConfig();

  // ---- items ----
  Future<ItemPage> listItems({
    String? q,
    String? kind,
    String? category,
    String status,
    bool lowStock,
    int page,
  });
  Future<InventoryItem> getItem(String id);
  Future<InventoryItem> createItem(ItemDraft draft);
  Future<InventoryItem> updateItem(String id, ItemDraft draft);
  Future<InventoryItem> archiveItem(String id);
  Future<InventoryItem> unarchiveItem(String id);

  // ---- movements (saldo) ----
  Future<List<InventoryMovement>> listMovements(String id);
  Future<InventoryMovement> registerMovement(String id, MovementDraft draft);

  /// Itens com saldo no/abaixo do mínimo (`GET /inventory/low-stock`).
  Future<List<InventoryItem>> lowStock();
}
