import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../domain/invoice_models.dart';

/// Filtro de status da lista (chip = chave do contrato com o backend + rótulo
/// PT-BR). `all` (key null) não envia filtro.
enum InvoiceStatusFilter {
  all(null, 'Todas'),
  authorized('authorized', 'Emitidas'),
  processing('processing', 'Processando'),
  rejected('rejected', 'Rejeitadas'),
  canceled('canceled', 'Canceladas');

  const InvoiceStatusFilter(this.key, this.label);
  final String? key;
  final String label;
}

/// Estado do filtro de status corrente da lista de notas.
class InvoiceStatusNotifier extends Notifier<InvoiceStatusFilter> {
  @override
  InvoiceStatusFilter build() => InvoiceStatusFilter.all;

  void set(InvoiceStatusFilter filter) => state = filter;
}

final invoiceStatusFilterProvider =
    NotifierProvider<InvoiceStatusNotifier, InvoiceStatusFilter>(
        InvoiceStatusNotifier.new);

/// Estado da lista paginada de notas. Dois modos: mobile acumula lotes
/// (infinite scroll via [loadMore]); desktop navega por página numerada
/// ([goToPage] substitui os itens).
class InvoiceListState {
  const InvoiceListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
    this.page = 1,
    this.pageSize = 20,
  });

  final List<Invoice> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final int page;
  final int pageSize;

  InvoiceListState copyWith({
    List<Invoice>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    int? page,
    int? pageSize,
  }) =>
      InvoiceListState(
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}

/// Lista de notas paginada. `build` carrega a 1ª página e reage ao filtro de
/// status (qualquer mudança reinicia da página 1); [loadMore] anexa o próximo
/// lote (mobile); [goToPage] substitui os itens (desktop). autoDispose: re-busca
/// ao reentrar na tela.
class InvoiceListNotifier extends AsyncNotifier<InvoiceListState> {
  int _page = 1;
  String? _status;

  @override
  Future<InvoiceListState> build() async {
    _status = ref.watch(invoiceStatusFilterProvider).key;
    _page = 1;
    final page = await _fetch(1);
    return InvoiceListState(
      items: page.items,
      total: page.total,
      hasMore: page.items.length < page.total,
      page: page.page,
      pageSize: page.pageSize,
    );
  }

  Future<InvoicePage> _fetch(int page) =>
      ref.read(invoiceRepositoryProvider).list(page: page, status: _status);

  /// Modo desktop (página numerada): SUBSTITUI os itens pela página pedida.
  Future<void> goToPage(int target) async {
    final current = state.asData?.value;
    if (current == null || current.loadingMore || target < 1) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(target);
      _page = target;
      state = AsyncData(InvoiceListState(
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
      state = AsyncData(InvoiceListState(
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

final invoiceListProvider =
    AsyncNotifierProvider.autoDispose<InvoiceListNotifier, InvoiceListState>(
        InvoiceListNotifier.new);

/// Uma nota por id (tela de detalhe), com linhas e eventos.
final invoiceProvider =
    FutureProvider.autoDispose.family<Invoice, String>((ref, id) {
  return ref.read(invoiceRepositoryProvider).getOne(id);
});

/// Notas de uma OS (para a integração natural na tela da OS: mostrar se já há
/// nota emitida e linkar, em vez de só um botão "Emitir").
final orderInvoicesProvider =
    FutureProvider.autoDispose.family<InvoicePage, String>((ref, orderId) {
  return ref.read(invoiceRepositoryProvider).list(orderId: orderId);
});
