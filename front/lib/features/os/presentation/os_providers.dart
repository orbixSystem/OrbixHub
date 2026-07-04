import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/os_models.dart';
import '../domain/os_repository.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final osRepositoryProvider = Provider<OsRepository>((ref) {
  throw UnimplementedError(
      'osRepositoryProvider must be overridden in di.dart');
});

/// Opções de ordenação da lista (chave de contrato com o backend + rótulo PT-BR).
enum OsSort {
  recent('recent', 'Mais recentes'),
  oldest('oldest', 'Mais antigas'),
  numberAsc('number_asc', 'Nº (crescente)'),
  numberDesc('number_desc', 'Nº (decrescente)'),
  customerAsc('customer_asc', 'Cliente (A–Z)'),
  customerDesc('customer_desc', 'Cliente (Z–A)'),
  totalDesc('total_desc', 'Maior valor'),
  totalAsc('total_asc', 'Menor valor'),
  status('status', 'Status');

  const OsSort(this.key, this.label);
  final String key;
  final String label;
}

/// Filtros correntes da lista de OS.
class OrderListQuery {
  const OrderListQuery({this.q, this.status, this.sort = OsSort.recent});

  final String? q;
  final String? status; // null = todas
  final OsSort sort;

  OrderListQuery copyWith({
    String? q,
    Object? status = _sentinel,
    OsSort? sort,
  }) =>
      OrderListQuery(
        q: q ?? this.q,
        status: status == _sentinel ? this.status : status as String?,
        sort: sort ?? this.sort,
      );

  static const _sentinel = Object();
}

/// Estado dos filtros (busca + status + ordenação).
class OrderListQueryNotifier extends Notifier<OrderListQuery> {
  @override
  OrderListQuery build() => const OrderListQuery();

  void setQuery(String value) =>
      state = state.copyWith(q: value.trim().isEmpty ? null : value.trim());

  /// Filtro de status: null = todas.
  void setStatus(String? status) => state = state.copyWith(status: status);

  void setSort(OsSort sort) => state = state.copyWith(sort: sort);
}

final orderListQueryProvider =
    NotifierProvider<OrderListQueryNotifier, OrderListQuery>(
        OrderListQueryNotifier.new);

/// Estado da lista paginada. Serve os DOIS modos do spec: mobile acumula
/// lotes (infinite scroll via [OrderListNotifier.loadMore]); desktop navega
/// por página numerada ([OrderListNotifier.goToPage] substitui os itens).
class OrderListState {
  const OrderListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
    this.page = 1,
    this.pageSize = 20,
  });

  final List<ServiceOrder> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;

  /// Página corrente (modo desktop; no modo scroll é a última carregada).
  final int page;
  final int pageSize;

  OrderListState copyWith({
    List<ServiceOrder>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    int? page,
    int? pageSize,
  }) =>
      OrderListState(
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}

/// Lista de OS paginada (scroll infinito). `build` carrega a 1ª página e reage
/// aos filtros (qualquer mudança reinicia da página 1); [loadMore] anexa o
/// próximo lote ao chegar perto do fim do scroll. autoDispose: re-busca ao
/// reentrar na tela.
class OrderListNotifier extends AsyncNotifier<OrderListState> {
  int _page = 1;
  late OrderListQuery _query;

  @override
  Future<OrderListState> build() async {
    _query = ref.watch(orderListQueryProvider);
    _page = 1;
    final page = await _fetch(1);
    return OrderListState(
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
      state = AsyncData(OrderListState(
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

  Future<OrderPage> _fetch(int page) =>
      ref.read(osRepositoryProvider).listOrders(
            q: _query.q,
            status: _query.status,
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
      state = AsyncData(OrderListState(
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

/// Lista de OS — reage aos filtros. autoDispose para re-buscar ao reentrar.
final orderListProvider =
    AsyncNotifierProvider.autoDispose<OrderListNotifier, OrderListState>(
        OrderListNotifier.new);

/// Uma OS por id (tela de detalhe).
final orderProvider =
    FutureProvider.autoDispose.family<ServiceOrder, String>((ref, id) {
  return ref.read(osRepositoryProvider).getOrder(id);
});

/// Lista de templates (com itens) — tela de gestão. autoDispose para re-buscar
/// ao reentrar; invalida após criar/editar/excluir.
final templateListProvider =
    FutureProvider.autoDispose<List<OsTemplate>>((ref) {
  return ref.read(osRepositoryProvider).listTemplatesFull();
});
