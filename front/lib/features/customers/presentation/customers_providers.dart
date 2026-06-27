import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/customers_models.dart';

/// Config do módulo (rótulo/campos dinâmicos). Kept-alive (estável na sessão),
/// mas reage ao tenant ativo: sem isso manteria em cache a config da empresa
/// anterior ao trocar de conta (login / logout / switch-tenant).
final customersConfigProvider = FutureProvider<CustomersConfig>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final tenantId =
      session is SessionAuthenticated ? session.me.activeTenant?.id : null;
  if (tenantId == null) {
    throw StateError('Nenhum tenant ativo na sessão.');
  }
  return ref.read(customersRepositoryProvider).fetchConfig();
});

/// Opções de ordenação da lista (chave de contrato com o backend + rótulo PT-BR).
enum CustomerSort {
  recent('recent', 'Mais recentes'),
  oldest('oldest', 'Mais antigos'),
  nameAsc('name_asc', 'Nome (A–Z)'),
  nameDesc('name_desc', 'Nome (Z–A)');

  const CustomerSort(this.key, this.label);
  final String key;
  final String label;
}

/// Filtros correntes da lista de clientes (busca + arquivados + ordenação).
class CustomerListQuery {
  const CustomerListQuery({
    this.q,
    this.showArchived = false,
    this.sort = CustomerSort.recent,
  });

  final String? q;

  /// off = só ativos; on = SÓ arquivados (nunca os dois ao mesmo tempo, nunca
  /// os soft-deleted).
  final bool showArchived;
  final CustomerSort sort;

  String get status => showArchived ? 'archived' : 'active';

  CustomerListQuery copyWith({
    String? q,
    bool? showArchived,
    CustomerSort? sort,
  }) =>
      CustomerListQuery(
        q: q ?? this.q,
        showArchived: showArchived ?? this.showArchived,
        sort: sort ?? this.sort,
      );
}

/// Estado dos filtros da lista de clientes (busca/arquivados/ordenação).
class CustomerListQueryNotifier extends Notifier<CustomerListQuery> {
  @override
  CustomerListQuery build() => const CustomerListQuery();

  void setQuery(String value) =>
      state = state.copyWith(q: value.trim().isEmpty ? null : value.trim());
  void setShowArchived(bool value) =>
      state = state.copyWith(showArchived: value);
  void setSort(CustomerSort sort) => state = state.copyWith(sort: sort);
}

final customerListQueryProvider =
    NotifierProvider<CustomerListQueryNotifier, CustomerListQuery>(
        CustomerListQueryNotifier.new);

/// Estado da lista paginada: clientes acumulados + se há mais lotes a carregar.
class CustomerListState {
  const CustomerListState({
    required this.items,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<Customer> items;
  final int total;
  final bool hasMore;
  final bool loadingMore;

  CustomerListState copyWith({
    List<Customer>? items,
    int? total,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      CustomerListState(
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Lista de clientes paginada (scroll infinito). `build` carrega a 1ª página e
/// reage aos filtros (qualquer mudança reinicia da página 1); [loadMore] anexa o
/// próximo lote ao chegar perto do fim do scroll. autoDispose: re-busca ao
/// reentrar na tela.
class CustomerListNotifier extends AsyncNotifier<CustomerListState> {
  int _page = 1;
  late CustomerListQuery _query;

  @override
  Future<CustomerListState> build() async {
    _query = ref.watch(customerListQueryProvider);
    _page = 1;
    final page = await _fetch(1);
    return CustomerListState(
      items: page.items,
      total: page.total,
      hasMore: page.items.length < page.total,
    );
  }

  Future<CustomerPage> _fetch(int page) =>
      ref.read(customersRepositoryProvider).listCustomers(
            q: _query.q,
            status: _query.status,
            sort: _query.sort.key,
            page: page,
          );

  /// Carrega o próximo lote e anexa. No-op se já carregando, sem mais páginas,
  /// ou ainda sem o 1º lote pronto. Em erro, mantém os itens atuais e para o
  /// spinner (a falha some no próximo scroll — sem derrubar a lista carregada).
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(_page + 1);
      _page += 1;
      final merged = [...current.items, ...next.items];
      state = AsyncData(CustomerListState(
        items: merged,
        total: next.total,
        hasMore: merged.length < next.total && next.items.isNotEmpty,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final customersListProvider =
    AsyncNotifierProvider.autoDispose<CustomerListNotifier, CustomerListState>(
        CustomerListNotifier.new);

/// Um cliente por id (tela de detalhe).
final customerProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) {
  return ref.read(customersRepositoryProvider).getCustomer(id);
});

/// Subjects de um cliente.
final subjectsForCustomerProvider =
    FutureProvider.autoDispose.family<SubjectPage, String>((ref, customerId) {
  return ref
      .read(customersRepositoryProvider)
      .listSubjects(customerId: customerId);
});

/// Filtro da timeline do cliente: id do veículo selecionado (null = todos).
typedef CustomerHistoryArgs = ({String customerId, String? subjectId});

/// Timeline do cliente (vazia até a OS existir), com filtro opcional por carro.
final customerHistoryProvider = FutureProvider.autoDispose
    .family<List<SubjectHistoryEntry>, CustomerHistoryArgs>((ref, args) {
  return ref
      .read(customersRepositoryProvider)
      .customerHistory(args.customerId, subjectId: args.subjectId);
});
