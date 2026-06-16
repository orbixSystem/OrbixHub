import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  throw UnimplementedError(
      'inventoryRepositoryProvider must be overridden in di.dart');
});

/// Config do módulo (campos dinâmicos da vertical). Estável na sessão.
final inventoryConfigProvider = FutureProvider<InventoryConfig>((ref) {
  return ref.read(inventoryRepositoryProvider).fetchConfig();
});

/// Filtros correntes da lista de itens.
class ItemListQuery {
  const ItemListQuery({
    this.q,
    this.category,
    this.active = 'true',
    this.lowStock = false,
  });

  final String? q;
  final String? category;
  final String active; // 'true' | 'false' | 'all'
  final bool lowStock;

  ItemListQuery copyWith({
    String? q,
    String? category,
    String? active,
    bool? lowStock,
  }) =>
      ItemListQuery(
        q: q ?? this.q,
        category: category,
        active: active ?? this.active,
        lowStock: lowStock ?? this.lowStock,
      );
}

/// Estado dos filtros (busca/categoria/baixo estoque).
class ItemListQueryNotifier extends Notifier<ItemListQuery> {
  @override
  ItemListQuery build() => const ItemListQuery();

  void setQuery(String value) =>
      state = state.copyWith(q: value.trim().isEmpty ? null : value.trim());
  void setCategory(String? category) => state = ItemListQuery(
        q: state.q,
        category: category,
        active: state.active,
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
        category: query.category,
        active: query.active,
        lowStock: query.lowStock,
      );
});

/// Um item por id (tela de detalhe).
final itemProvider =
    FutureProvider.autoDispose.family<InventoryItem, String>((ref, id) {
  return ref.read(inventoryRepositoryProvider).getItem(id);
});
