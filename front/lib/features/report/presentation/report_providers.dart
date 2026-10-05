import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cashier/domain/cashier_models.dart';
import '../../cashier/presentation/cashier_providers.dart';
import '../domain/monthly_models.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';
import 'report_catalog.dart';
import 'report_tabs.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  throw UnimplementedError(
      'reportRepositoryProvider must be overridden in di.dart');
});

/// O período de TODOS os relatórios — derivado do mês escolhido no topo.
///
/// Antes vinha do seletor do dashboard, e o resultado era uma tela com duas
/// respostas para "quando": o cabeçalho dizia "Setembro/2026" e a aba abaixo
/// mostrava os últimos 30 dias. Os números não batiam entre as abas, e não
/// havia como o usuário saber qual dos dois estava certo.
///
/// Mês corrente vai até AGORA, não até o fim do mês: somar os dias que ainda
/// não aconteceram achataria qualquer média.
final reportRangeProvider = Provider<ReportRange>((ref) {
  final mes = ref.watch(mesSelecionadoProvider);
  final agora = DateTime.now();
  if (mes == null) {
    return ReportRange(from: DateTime(agora.year, agora.month, 1), to: agora);
  }
  final partes = mes.split('-');
  final ano = int.tryParse(partes.first) ?? agora.year;
  final m = partes.length > 1 ? (int.tryParse(partes[1]) ?? agora.month) : agora.month;
  final inicio = DateTime(ano, m, 1);
  // Último instante do mês: dia 0 do mês seguinte é o último dia deste.
  final fim = DateTime(ano, m + 1, 0, 23, 59, 59, 999);
  return ReportRange(from: inicio, to: fim.isAfter(agora) ? agora : fim);
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

/// Aba aberta em Relatórios. Começa no relatório escrito do mês.
///
/// `autoDispose` de propósito: Relatórios SEMPRE abre na mesma página — a
/// leitura do mês em palavras. Guardado, o provider devolvia o usuário à
/// última aba que ele tinha aberto dias antes, e quem voltasse para "ver como
/// foi o mês" caía numa tabela de estoque sem entender por quê. Trocar de aba
/// durante a visita continua funcionando: enquanto a tela existe, alguém está
/// observando.
final selectedTabProvider =
    NotifierProvider.autoDispose<SelectedTabController, ReportTab>(
  SelectedTabController.new,
);

class SelectedTabController extends Notifier<ReportTab> {
  @override
  ReportTab build() => ReportTab.resumo;

  void select(ReportTab tab) => state = tab;
}

/// Mês analisado, no formato "2026-09". `null` = mês corrente.
///
/// Separado do seletor de período do dashboard de propósito: a leitura mensal é
/// de MÊS FECHADO — um intervalo "últimos 30 dias" não tem mês anterior com que
/// se comparar, e a comparação é metade do valor desta tela.
final mesSelecionadoProvider =
    NotifierProvider<MesSelecionadoController, String?>(
  MesSelecionadoController.new,
);

class MesSelecionadoController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? mes) => state = mes;
}

/// A leitura do mês (KPIs + sinais), calculada no servidor.
final visaoMensalProvider = FutureProvider<VisaoMensal>((ref) {
  final mes = ref.watch(mesSelecionadoProvider);
  return ref.watch(reportRepositoryProvider).overview(mes: mes);
});

/// O resumo ESCRITO do mês fechado, com os meses disponíveis.
///
/// Separado da visão porque as duas falham de formas diferentes: um mês
/// corrente simplesmente não tem resumo (ele nasce no dia 1º), e isso não é
/// erro — a tela mostra os números e explica que o texto vem quando o mês
/// fechar.
final resumoMensalProvider = FutureProvider<ResumoMensalPagina>((ref) {
  final mes = ref.watch(mesSelecionadoProvider);
  return ref.watch(reportRepositoryProvider).resumoMensal(mes: mes);
});

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

/// Despesas por categoria no período selecionado.
final expensesReportProvider =
    FutureProvider.autoDispose<ExpensesReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).expensesReport(range: range);
});

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

/// Resumo de clientes para a Visão geral (KPI "Novos clientes"): só precisa de
/// `newInRange`/`active` — busca 1 linha para não carregar a lista à toa
/// (`newInRange` é o TOTAL do período, independente da página).
final customersReportProvider =
    FutureProvider.autoDispose<CustomersReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref
      .read(reportRepositoryProvider)
      .customers(range: range, page: 1, pageSize: 1);
});

/// Linhas por página do relatório de clientes (scroll infinito na tela).
const customersReportPageSize = 50;

/// Estado da lista paginada do relatório de clientes: linhas acumuladas +
/// resumo (ativos/novos) + série do gráfico (independente da paginação).
class CustomersReportListState {
  const CustomersReportListState({
    required this.rows,
    required this.total,
    required this.hasMore,
    required this.active,
    required this.series,
    this.loadingMore = false,
  });

  final List<CustomerReportRow> rows;
  final int total;
  final bool hasMore;
  final int active;
  final List<CustomersSeriesPoint> series;
  final bool loadingMore;

  /// Novos no período = total do período (o backend já manda o TOTAL).
  int get newInRange => total;

  CustomersReportListState copyWith({
    List<CustomerReportRow>? rows,
    int? total,
    bool? hasMore,
    int? active,
    List<CustomersSeriesPoint>? series,
    bool? loadingMore,
  }) =>
      CustomersReportListState(
        rows: rows ?? this.rows,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        active: active ?? this.active,
        series: series ?? this.series,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Clientes PAGINADO (scroll infinito): `build` carrega a 1ª página e reage ao
/// período (mudança reinicia da página 1); [loadMore] anexa o próximo lote.
/// Evita carregar todos os clientes do período de uma vez (causa do travamento
/// da tela). autoDispose: re-busca ao reentrar. Espelha o notifier da OS.
class CustomersReportListNotifier
    extends AsyncNotifier<CustomersReportListState> {
  int _page = 1;
  late ReportRange _range;

  @override
  Future<CustomersReportListState> build() async {
    _range = ref.watch(reportRangeProvider);
    _page = 1;
    final p = await _fetch(1);
    return CustomersReportListState(
      rows: p.rows,
      total: p.total,
      hasMore: p.rows.length < p.total,
      active: p.active,
      series: p.series,
    );
  }

  Future<CustomersReport> _fetch(int page) =>
      ref.read(reportRepositoryProvider).customers(
            range: _range,
            page: page,
            pageSize: customersReportPageSize,
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
      state = AsyncData(CustomersReportListState(
        rows: merged,
        total: next.total,
        hasMore: merged.length < next.total && next.rows.isNotEmpty,
        active: next.active,
        series: next.series,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final customersReportListProvider = AsyncNotifierProvider.autoDispose<
    CustomersReportListNotifier, CustomersReportListState>(
  CustomersReportListNotifier.new,
);

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

/// Os mais vendidos do painel de Ordens, por tipo.
///
/// Dedicado, e não o `topItemsReportProvider`: aquele obedece ao filtro de
/// tipo da tabela, e o painel precisa mostrar serviço E peça lado a lado. Com
/// o mesmo provider, escolher "peças" na tabela esvaziaria o card de serviços
/// sem nada na tela explicando por quê.
final painelTopItensProvider = FutureProvider.autoDispose
    .family<TopItemsReport, String>((ref, kind) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).topItems(
        range: range,
        kind: kind,
        limit: 8,
      );
});

/// A página do painel de Estoque.
///
/// Página grande de propósito (e separada da tabela, que pagina de 50 em 50):
/// o painel precisa ordenar o estoque por valor e por risco, e um ranking
/// feito sobre as cinquenta primeiras linhas alfabéticas não é um ranking — é
/// uma amostra que se parece com um. 200 é o teto que o endpoint aceita; acima
/// disso o painel avisa que está lendo uma parte.
const painelEstoqueLimite = 200;

final painelEstoqueProvider =
    FutureProvider.autoDispose<InventoryReport>((ref) {
  return ref
      .read(reportRepositoryProvider)
      .inventory(page: 1, pageSize: painelEstoqueLimite);
});
