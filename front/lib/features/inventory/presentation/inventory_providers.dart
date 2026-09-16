import 'dart:async';

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

/// Opções de ordenação da lista (chave de contrato com o backend + rótulo PT-BR).
enum ItemSort {
  nameAsc('name_asc', 'Nome (A–Z)'),
  nameDesc('name_desc', 'Nome (Z–A)'),
  priceDesc('price_desc', 'Maior preço'),
  priceAsc('price_asc', 'Menor preço'),
  stockDesc('stock_desc', 'Maior estoque'),
  stockAsc('stock_asc', 'Menor estoque'),
  recent('recent', 'Mais recentes');

  const ItemSort(this.key, this.label);
  final String key;
  final String label;
}

/// Filtros correntes da lista de itens.
class ItemListQuery {
  const ItemListQuery({
    this.q,
    this.category,
    this.kind,
    this.active = 'true',
    this.lowStock = false,
    this.outOfStock = false,
    this.sort = ItemSort.nameAsc,
  });

  final String? q;
  final String? category;
  final String? kind; // null (todos) | 'product' | 'service'
  final String active; // 'true' | 'false' | 'all'
  final bool lowStock;

  /// Só os zerados. Separado de [lowStock] porque "acabou" e "está acabando"
  /// são perguntas diferentes na hora de repor.
  final bool outOfStock;
  final ItemSort sort;

  /// Algum filtro capaz de **esconder** itens está ligado? `active: 'true'` é o
  /// padrão da tela (não é escolha do usuário) e `sort` só reordena — nenhum
  /// dos dois conta. Serve para a lista vazia dizer a verdade: "seus itens
  /// estão lá, os filtros é que esconderam" em vez de "cadastre produtos".
  bool get hasHidingFilters =>
      (q != null && q!.isNotEmpty) ||
      category != null ||
      kind != null ||
      lowStock ||
      outOfStock ||
      active != 'true';

  /// `q` com sentinela: `q ?? this.q` faria `null` (limpar a busca) devolver o
  /// texto antigo — apagar o campo deixava a lista filtrada para sempre.
  static const _sentinel = Object();

  ItemListQuery copyWith({
    Object? q = _sentinel,
    String? category,
    String? kind,
    String? active,
    bool? lowStock,
    bool? outOfStock,
    ItemSort? sort,
  }) =>
      ItemListQuery(
        q: q == _sentinel ? this.q : q as String?,
        category: category,
        kind: kind ?? this.kind,
        active: active ?? this.active,
        lowStock: lowStock ?? this.lowStock,
        outOfStock: outOfStock ?? this.outOfStock,
        sort: sort ?? this.sort,
      );
}

/// Estado dos filtros (busca/categoria/baixo estoque/ordenação).
class ItemListQueryNotifier extends Notifier<ItemListQuery> {
  Timer? _debounce;

  @override
  ItemListQuery build() {
    ref.onDispose(() => _debounce?.cancel());
    return const ItemListQuery();
  }

  /// Busca com espera — ver `OrderListQueryNotifier.setQuery`: sem isto, cada
  /// tecla dispara uma requisição, e as intermediárias ficam penduradas.
  void setQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      final novo = q.isEmpty ? null : q;
      if (novo == state.q) return;
      state = state.copyWith(q: novo);
    });
  }
  void setCategory(String? category) => state = ItemListQuery(
        q: state.q,
        category: category,
        kind: state.kind,
        active: state.active,
        lowStock: state.lowStock,
        outOfStock: state.outOfStock,
        sort: state.sort,
      );

  /// Filtro por tipo: null = todos, 'product' ou 'service'.
  void setKind(String? kind) => state = ItemListQuery(
        q: state.q,
        category: state.category,
        kind: kind,
        active: state.active,
        lowStock: state.lowStock,
        outOfStock: state.outOfStock,
        sort: state.sort,
      );
  /// "Estoque baixo" e "Esgotados" são recortes diferentes da mesma pergunta,
  /// e um contém o outro — ligar os dois juntos não diria nada. Ligar um
  /// desliga o outro.
  void setLowStock(bool value) =>
      state = state.copyWith(lowStock: value, outOfStock: false);

  void setOutOfStock(bool value) =>
      state = state.copyWith(outOfStock: value, lowStock: false);
  void setSort(ItemSort sort) => state = state.copyWith(sort: sort);

  /// Zera tudo que esconde item, preservando a ordenação escolhida (ordenar não
  /// esconde nada, e refazer essa escolha só irritaria). `copyWith` não serve
  /// aqui: ele não consegue voltar `q`/`category`/`kind` para null.
  void clearFilters() => state = ItemListQuery(sort: state.sort);
}

/// **autoDispose de propósito**: sair da tela de Estoque zera busca e filtros.
///
/// Enquanto este provider sobrevivia à saída da tela, o `TextEditingController`
/// da busca — que nasce vazio a cada montagem — passava a mentir: a caixa em
/// branco e a lista obedecendo a um termo antigo. Em produção (19/08/2026) um
/// tenant com 21 itens via só 2 ao voltar para o Estoque; eram exatamente os
/// dois que continham o "t" de uma busca abandonada minutos antes.
///
/// Preservar filtro só se justificaria se houvesse ida-e-volta para um detalhe
/// em outra rota. Não há: `/m/inventory` é rota única e a ficha do item abre
/// inline na própria lista.
final itemListQueryProvider =
    NotifierProvider.autoDispose<ItemListQueryNotifier, ItemListQuery>(
        ItemListQueryNotifier.new);

/// Estado da lista paginada. Dois modos (spec): mobile acumula lotes
/// (infinite scroll via [ItemListNotifier.loadMore]); desktop navega por
/// página numerada ([ItemListNotifier.goToPage] substitui os itens).
class ItemListState {
  const ItemListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
    this.page = 1,
    this.pageSize = 20,
  });

  final List<InventoryItem> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final int page;
  final int pageSize;

  ItemListState copyWith({
    List<InventoryItem>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    int? page,
    int? pageSize,
  }) =>
      ItemListState(
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}

/// Lista de itens paginada (scroll infinito). `build` carrega a 1ª página e reage
/// aos filtros (qualquer mudança reinicia da página 1); [loadMore] anexa o próximo
/// lote ao chegar perto do fim do scroll. autoDispose: re-busca ao reentrar na tela.
class ItemListNotifier extends AsyncNotifier<ItemListState> {
  int _page = 1;
  late ItemListQuery _query;

  @override
  Future<ItemListState> build() async {
    _query = ref.watch(itemListQueryProvider);
    _page = 1;
    final page = await _fetch(1);
    return ItemListState(
      items: page.items,
      total: page.total,
      hasMore: page.items.length < page.total,
      page: page.page,
      pageSize: page.pageSize,
    );
  }

  /// Modo desktop (página numerada): SUBSTITUI os itens pela página pedida.
  Future<void> goToPage(int target) async {
    final current = state.asData?.value;
    if (current == null || current.loadingMore || target < 1) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(target);
      _page = target;
      state = AsyncData(ItemListState(
        items: next.items,
        total: next.total,
        hasMore: target * next.pageSize < next.total,
        page: target,
        pageSize: next.pageSize,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<ItemPage> _fetch(int page) =>
      ref.read(inventoryRepositoryProvider).listItems(
            q: _query.q,
            category: _query.category,
            kind: _query.kind,
            active: _query.active,
            lowStock: _query.lowStock,
            outOfStock: _query.outOfStock,
            sort: _query.sort.key,
            page: page,
          );

  /// Carrega o próximo lote e anexa. No-op se já carregando, sem mais páginas,
  /// ou ainda sem o 1º lote pronto. Em erro, mantém os itens atuais e para o
  /// spinner (a falha some no próximo scroll — sem derrubar a lista já carregada).
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(_page + 1);
      _page += 1;
      final merged = [...current.items, ...next.items];
      state = AsyncData(ItemListState(
        items: merged,
        total: next.total,
        hasMore: merged.length < next.total && next.items.isNotEmpty,
        page: _page,
        pageSize: next.pageSize,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final itemListProvider =
    AsyncNotifierProvider.autoDispose<ItemListNotifier, ItemListState>(
        ItemListNotifier.new);

/// Um item por id (tela de detalhe).
final itemProvider =
    FutureProvider.autoDispose.family<InventoryItem, String>((ref, id) {
  return ref.read(inventoryRepositoryProvider).getItem(id);
});
