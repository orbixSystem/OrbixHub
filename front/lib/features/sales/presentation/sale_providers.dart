import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/sale_models.dart';

/// Filtro de status da lista (chip = chave do contrato + rótulo PT-BR).
/// `all` (key null) não envia filtro.
enum SaleStatusFilter {
  all(null, 'Todas'),
  concluida('concluida', 'Concluídas'),
  cancelada('cancelada', 'Canceladas');

  const SaleStatusFilter(this.key, this.label);
  final String? key;
  final String label;
}

/// Estado do filtro de status corrente da lista de vendas.
class SaleStatusNotifier extends Notifier<SaleStatusFilter> {
  @override
  SaleStatusFilter build() => SaleStatusFilter.all;

  void set(SaleStatusFilter filter) => state = filter;
}

final saleStatusFilterProvider =
    NotifierProvider<SaleStatusNotifier, SaleStatusFilter>(
        SaleStatusNotifier.new);

/// Estado da lista paginada de vendas. Dois modos: mobile acumula lotes
/// (infinite scroll via [loadMore]); desktop navega por página numerada
/// ([goToPage] substitui os itens).
class SaleListState {
  const SaleListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
    this.page = 1,
    this.pageSize = 20,
  });

  final List<Sale> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final int page;
  final int pageSize;

  SaleListState copyWith({
    List<Sale>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    int? page,
    int? pageSize,
  }) =>
      SaleListState(
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}

/// Lista de vendas paginada. `build` carrega a 1ª página e reage ao filtro de
/// status (qualquer mudança reinicia da página 1); [loadMore] anexa o próximo
/// lote (mobile); [goToPage] substitui os itens (desktop). autoDispose: re-busca
/// ao reentrar na tela.
class SaleListNotifier extends AsyncNotifier<SaleListState> {
  int _page = 1;
  String? _status;

  @override
  Future<SaleListState> build() async {
    _status = ref.watch(saleStatusFilterProvider).key;
    _page = 1;
    final page = await _fetch(1);
    return SaleListState(
      items: page.items,
      total: page.total,
      hasMore: page.items.length < page.total,
      page: page.page,
      pageSize: page.pageSize,
    );
  }

  Future<SalePage> _fetch(int page) =>
      ref.read(saleRepositoryProvider).list(page: page, status: _status);

  /// Modo desktop (página numerada): SUBSTITUI os itens pela página pedida.
  Future<void> goToPage(int target) async {
    final current = state.asData?.value;
    if (current == null || current.loadingMore || target < 1) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(target);
      _page = target;
      state = AsyncData(SaleListState(
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

  /// Carrega o próximo lote e anexa (mobile). No-op se já carregando, sem mais
  /// páginas ou sem o 1º lote pronto. Em erro, mantém os itens e para o spinner.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(_page + 1);
      _page += 1;
      final merged = [...current.items, ...next.items];
      state = AsyncData(SaleListState(
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

final saleListProvider =
    AsyncNotifierProvider.autoDispose<SaleListNotifier, SaleListState>(
        SaleListNotifier.new);

/// Uma venda por id (tela de detalhe), com itens.
final saleProvider =
    FutureProvider.autoDispose.family<Sale, String>((ref, id) {
  return ref.read(saleRepositoryProvider).getOne(id);
});
