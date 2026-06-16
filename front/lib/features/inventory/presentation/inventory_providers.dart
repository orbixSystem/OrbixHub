import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  throw UnimplementedError(
      'inventoryRepositoryProvider must be overridden in di.dart');
});

/// Config do módulo (unidade/categorias/margem padrão). Estável na sessão.
final inventoryConfigProvider = FutureProvider<InventoryConfig>((ref) {
  return ref.read(inventoryRepositoryProvider).fetchConfig();
});

/// Filtros correntes da lista de itens.
class ItemListQuery {
  const ItemListQuery({
    this.q,
    this.kind,
    this.status = 'active',
    this.lowStock = false,
  });

  final String? q;
  final String? kind; // null = todos | 'product' | 'service'
  final String status;
  final bool lowStock;

  ItemListQuery copyWith({
    String? q,
    String? kind,
    String? status,
    bool? lowStock,
  }) =>
      ItemListQuery(
        q: q ?? this.q,
        kind: kind,
        status: status ?? this.status,
        lowStock: lowStock ?? this.lowStock,
      );
}

/// Estado dos filtros (busca/tipo/baixo estoque).
class ItemListQueryNotifier extends Notifier<ItemListQuery> {
  @override
  ItemListQuery build() => const ItemListQuery();

  void setQuery(String value) =>
      state = state.copyWith(q: value.trim().isEmpty ? null : value.trim());
  void setKind(String? kind) =>
      state = ItemListQuery(
        q: state.q,
        kind: kind,
        status: state.status,
        lowStock: state.lowStock,
      );
  void setLowStock(bool value) => state = state.copyWith(lowStock: value);
}

final itemListQueryProvider =
    NotifierProvider<ItemListQueryNotifier, ItemListQuery>(
        ItemListQueryNotifier.new);

/// Lista de itens — reage aos filtros. autoDispose para re-buscar ao reentrar.
final itemListProvider = FutureProvider.autoDispose<ItemPage>((ref) {
  final query = ref.watch(itemListQueryProvider);
  return ref.read(inventoryRepositoryProvider).listItems(
        q: query.q,
        kind: query.kind,
        status: query.status,
        lowStock: query.lowStock,
      );
});

/// Um item por id (tela de detalhe).
final itemProvider =
    FutureProvider.autoDispose.family<InventoryItem, String>((ref, id) {
  return ref.read(inventoryRepositoryProvider).getItem(id);
});

/// Histórico de movimentos de um item.
final itemMovementsProvider = FutureProvider.autoDispose
    .family<List<InventoryMovement>, String>((ref, id) {
  return ref.read(inventoryRepositoryProvider).listMovements(id);
});
