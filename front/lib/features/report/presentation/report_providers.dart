import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../../dashboard/domain/dashboard_models.dart';
import '../../dashboard/presentation/period_controller.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';
import 'report_catalog.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  throw UnimplementedError(
      'reportRepositoryProvider must be overridden in di.dart');
});

/// Converte o `MetricsRange` do seletor de período (reusado do dashboard) no
/// `ReportRange` desta feature. Reage à seleção de período.
final reportRangeProvider = Provider<ReportRange>((ref) {
  final MetricsRange r = ref.watch(metricsRangeProvider);
  return ReportRange(from: r.from, to: r.to);
});

/// Relatório selecionado no seletor. Default: o primeiro disponível (definido na
/// tela ao montar). `null` = nenhum disponível.
final selectedReportProvider =
    NotifierProvider<SelectedReportController, ReportKind?>(
  SelectedReportController.new,
);

class SelectedReportController extends Notifier<ReportKind?> {
  @override
  ReportKind? build() => null;

  void select(ReportKind kind) => state = kind;
}

/// Opções de ordenação do relatório operacional de OS (chave = contrato com o
/// backend; rótulo PT-BR). `recent` é o default.
enum OsReportSort {
  recent('recent', 'Mais recentes'),
  oldest('oldest', 'Mais antigas'),
  numberAsc('number_asc', 'Nº (crescente)'),
  numberDesc('number_desc', 'Nº (decrescente)'),
  customerAsc('customer_asc', 'Cliente (A–Z)'),
  customerDesc('customer_desc', 'Cliente (Z–A)'),
  totalDesc('total_desc', 'Maior valor'),
  totalAsc('total_asc', 'Menor valor'),
  status('status', 'Status');

  const OsReportSort(this.key, this.label);
  final String key;
  final String label;
}

/// Filtros contextuais dos relatórios de OS.
class ReportFilters {
  const ReportFilters({
    this.assignedTo,
    this.status,
    this.kind,
    this.limit = 10,
    this.osQ,
    this.osSort = OsReportSort.recent,
    this.saleType,
    this.salePaymentStatus,
  });

  /// Técnico (uuid do membro) — OS operacional.
  final String? assignedTo;

  /// Status da OS — OS operacional.
  final String? status;

  /// Tipo (product/service) — top-itens.
  final String? kind;

  /// Top N — top-itens.
  final int limit;

  /// Busca (nº/cliente) — OS operacional.
  final String? osQ;

  /// Ordenação — OS operacional.
  final OsReportSort osSort;

  /// Tipo (servico/produto) — lente Vendas.
  final String? saleType;

  /// Status de pagamento (a_receber/parcial/pago) — lente Vendas.
  final String? salePaymentStatus;

  ReportFilters copyWith({
    String? assignedTo,
    bool clearAssignedTo = false,
    String? status,
    bool clearStatus = false,
    String? kind,
    bool clearKind = false,
    int? limit,
    String? osQ,
    bool clearOsQ = false,
    OsReportSort? osSort,
    String? saleType,
    bool clearSaleType = false,
    String? salePaymentStatus,
    bool clearSalePaymentStatus = false,
  }) =>
      ReportFilters(
        assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
        status: clearStatus ? null : (status ?? this.status),
        kind: clearKind ? null : (kind ?? this.kind),
        limit: limit ?? this.limit,
        osQ: clearOsQ ? null : (osQ ?? this.osQ),
        osSort: osSort ?? this.osSort,
        saleType: clearSaleType ? null : (saleType ?? this.saleType),
        salePaymentStatus: clearSalePaymentStatus
            ? null
            : (salePaymentStatus ?? this.salePaymentStatus),
      );
}

final reportFiltersProvider =
    NotifierProvider<ReportFiltersController, ReportFilters>(
  ReportFiltersController.new,
);

class ReportFiltersController extends Notifier<ReportFilters> {
  @override
  ReportFilters build() => const ReportFilters();

  void setAssignedTo(String? id) => state = (id == null || id.isEmpty)
      ? state.copyWith(clearAssignedTo: true)
      : state.copyWith(assignedTo: id);

  void setStatus(String? status) => state = (status == null || status.isEmpty)
      ? state.copyWith(clearStatus: true)
      : state.copyWith(status: status);

  void setKind(String? kind) => state = (kind == null || kind.isEmpty)
      ? state.copyWith(clearKind: true)
      : state.copyWith(kind: kind);

  void setLimit(int limit) => state = state.copyWith(limit: limit);

  void setOsQ(String? q) => state = (q == null || q.trim().isEmpty)
      ? state.copyWith(clearOsQ: true)
      : state.copyWith(osQ: q.trim());

  void setOsSort(OsReportSort sort) => state = state.copyWith(osSort: sort);

  void setSaleType(String? type) => state = (type == null || type.isEmpty)
      ? state.copyWith(clearSaleType: true)
      : state.copyWith(saleType: type);

  void setSalePaymentStatus(String? s) => state = (s == null || s.isEmpty)
      ? state.copyWith(clearSalePaymentStatus: true)
      : state.copyWith(salePaymentStatus: s);
}

/// Membros da equipe (para o filtro "técnico"). autoDispose: re-busca ao reentrar.
final reportMembersProvider =
    FutureProvider.autoDispose<List<ReportMemberOption>>((ref) {
  return ref.read(reportRepositoryProvider).members();
});

// --- Providers de dados, um por relatório. Reagem a período + filtros. ---

/// Linhas por página do relatório operacional de OS (scroll infinito na tela).
const osReportPageSize = 50;

/// Estado da lista paginada do relatório de OS: linhas acumuladas + se há mais.
class OsReportListState {
  const OsReportListState({
    required this.rows,
    required this.total,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<OsReportRow> rows;
  final int total;
  final bool hasMore;
  final bool loadingMore;

  OsReportListState copyWith({
    List<OsReportRow>? rows,
    int? total,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      OsReportListState(
        rows: rows ?? this.rows,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// OS operacional PAGINADA (scroll infinito): `build` carrega a 1ª página e reage
/// a período/filtros/busca/ordenação (qualquer mudança reinicia da página 1);
/// [loadMore] anexa o próximo lote. Evita carregar milhares de linhas de uma vez
/// (causa do travamento da tela). autoDispose: re-busca ao reentrar.
class OsReportListNotifier extends AsyncNotifier<OsReportListState> {
  int _page = 1;
  late ReportRange _range;
  late ReportFilters _filters;

  @override
  Future<OsReportListState> build() async {
    _range = ref.watch(reportRangeProvider);
    _filters = ref.watch(reportFiltersProvider);
    _page = 1;
    final p = await _fetch(1);
    return OsReportListState(
      rows: p.rows,
      total: p.total,
      hasMore: p.rows.length < p.total,
    );
  }

  Future<OsOperationalReport> _fetch(int page) =>
      ref.read(reportRepositoryProvider).osReport(
            range: _range,
            assignedTo: _filters.assignedTo,
            status: _filters.status,
            q: _filters.osQ,
            sort: _filters.osSort.key,
            page: page,
            pageSize: osReportPageSize,
          );

  /// Carrega o próximo lote e anexa. No-op se já carregando, sem mais páginas ou
  /// sem o 1º lote pronto. Em erro, mantém as linhas atuais e para o spinner.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(_page + 1);
      _page += 1;
      final merged = [...current.rows, ...next.rows];
      state = AsyncData(OsReportListState(
        rows: merged,
        total: next.total,
        hasMore: merged.length < next.total && next.rows.isNotEmpty,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final osOperationalReportProvider =
    AsyncNotifierProvider.autoDispose<OsReportListNotifier, OsReportListState>(
  OsReportListNotifier.new,
);

final revenueReportProvider =
    FutureProvider.autoDispose<RevenueReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).revenue(range: range);
});

final teamReportProvider = FutureProvider.autoDispose<TeamReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).team(range: range);
});

final topItemsReportProvider =
    FutureProvider.autoDispose<TopItemsReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  final filters = ref.watch(reportFiltersProvider);
  return ref.read(reportRepositoryProvider).topItems(
        range: range,
        kind: filters.kind,
        limit: filters.limit,
      );
});

/// Tamanho da página do relatório de estoque (linhas por página na tela).
const inventoryPageSize = 50;

/// Página atual (1-based) do relatório de estoque. autoDispose: zera ao sair.
final inventoryPageProvider =
    NotifierProvider.autoDispose<InventoryPageController, int>(
  InventoryPageController.new,
);

class InventoryPageController extends Notifier<int> {
  @override
  int build() => 1;

  void set(int page) => state = page < 1 ? 1 : page;
}

/// Posição de estoque PAGINADA — reage à página selecionada. autoDispose +
/// keepAlive curto evitaria flicker, mas aqui simples: re-busca por página.
final inventoryReportProvider =
    FutureProvider.autoDispose<InventoryReport>((ref) {
  final page = ref.watch(inventoryPageProvider);
  return ref.read(reportRepositoryProvider).inventory(
        page: page,
        pageSize: inventoryPageSize,
      );
});

final customersReportProvider =
    FutureProvider.autoDispose<CustomersReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).customers(range: range);
});

/// Detalhamento linha-a-linha do faturamento (OS + venda avulsa) no período —
/// alimenta a seção "Detalhamento" da lente Faturamento. Reage ao período.
final salesLedgerReportProvider =
    FutureProvider.autoDispose<SalesLedger>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).salesLedger(range: range);
});

/// Recebido no caixa por forma de pagamento (entrou/saiu/saldo) no período —
/// alimenta a lente "Caixa" do Relatório. Vem do módulo Caixa (`/cashier/summary`,
/// gated por cashier.manage — que o gestor já tem). É "recebido", não faturamento.
final cashierRecebidoReportProvider =
    FutureProvider.autoDispose<CashSummary>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(cashierRepositoryProvider).summary(
        from: range.fromIso,
        to: range.toIso,
      );
});
