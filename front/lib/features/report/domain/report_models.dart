import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_models.freezed.dart';
part 'report_models.g.dart';

/// Janela de tempo resolvida no front e enviada como `?from=ISO&to=ISO`.
/// (Espelha o `MetricsRange` do dashboard; mantido aqui para a feature `report`
/// ser autocontida — o seletor de período é reusado de `features/dashboard`.)
class ReportRange {
  const ReportRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  String get fromIso => from.toUtc().toIso8601String();
  String get toIso => to.toUtc().toIso8601String();
}

// ---------------------------------------------------------------------------
// OS operacional — GET /report/os
// ---------------------------------------------------------------------------

/// Linha do relatório operacional de OS (`GET /report/os` → `rows`).
@freezed
abstract class OsReportRow with _$OsReportRow {
  const factory OsReportRow({
    required String number,
    @JsonKey(name: 'customer_name') @Default('') String customerName,
    @Default('') String status,
    @JsonKey(name: 'assigned_to') String? assignedTo,
    @Default(0) num total,
    @JsonKey(name: 'opened_at') String? openedAt,
    @JsonKey(name: 'finished_at') String? finishedAt,
    @JsonKey(name: 'cycleMs') num? cycleMs,
  }) = _OsReportRow;

  factory OsReportRow.fromJson(Map<String, dynamic> json) =>
      _$OsReportRowFromJson(json);
}

/// Agregado por status/técnico de uma linha (count + revenue).
@freezed
abstract class CountRevenue with _$CountRevenue {
  const factory CountRevenue({
    @Default(0) int count,
    @Default(0) num revenue,
  }) = _CountRevenue;

  factory CountRevenue.fromJson(Map<String, dynamic> json) =>
      _$CountRevenueFromJson(json);
}

/// Relatório operacional de OS PAGINADO (scroll infinito na tela): linhas da
/// página + `total`/`page`/`pageSize`. (Os agregados `byStatus`/`byAssignedTo`
/// ficaram opcionais — o backend paginado não os envia mais; default vazio.)
@freezed
abstract class OsOperationalReport with _$OsOperationalReport {
  const factory OsOperationalReport({
    @Default(<OsReportRow>[]) List<OsReportRow> rows,
    @Default(0) int total,
    @Default(1) int page,
    @JsonKey(name: 'pageSize') @Default(50) int pageSize,
    @JsonKey(name: 'byStatus') @Default(<String, int>{}) Map<String, int> byStatus,
    @JsonKey(name: 'byAssignedTo')
    @Default(<String, CountRevenue>{})
    Map<String, CountRevenue> byAssignedTo,
  }) = _OsOperationalReport;

  factory OsOperationalReport.fromJson(Map<String, dynamic> json) =>
      _$OsOperationalReportFromJson(json);
}

// ---------------------------------------------------------------------------
// Faturamento — GET /report/revenue
// ---------------------------------------------------------------------------

/// Faturamento de um dia do calendário (série temporal).
@freezed
abstract class RevenueByDay with _$RevenueByDay {
  const factory RevenueByDay({
    @Default('') String day,
    @Default(0) num revenue,
    @Default(0) int count,
  }) = _RevenueByDay;

  factory RevenueByDay.fromJson(Map<String, dynamic> json) =>
      _$RevenueByDayFromJson(json);
}

/// Relatório de faturamento: total, ticket médio, série por dia, quebra por status.
@freezed
abstract class RevenueReport with _$RevenueReport {
  const factory RevenueReport({
    @Default(0) num total,
    @JsonKey(name: 'avgTicket') @Default(0) num avgTicket,
    @JsonKey(name: 'byDay') @Default(<RevenueByDay>[]) List<RevenueByDay> byDay,
    @JsonKey(name: 'byStatus')
    @Default(<String, CountRevenue>{})
    Map<String, CountRevenue> byStatus,
  }) = _RevenueReport;

  factory RevenueReport.fromJson(Map<String, dynamic> json) =>
      _$RevenueReportFromJson(json);
}

// ---------------------------------------------------------------------------
// Rendimento da equipe — GET /report/team
// ---------------------------------------------------------------------------

/// Linha do rendimento da equipe (agregada por responsável).
@freezed
abstract class TeamReportRow with _$TeamReportRow {
  const factory TeamReportRow({
    @JsonKey(name: 'assignedTo') String? assignedTo,
    @Default(0) int orders,
    @Default(0) int completed,
    @Default(0) num revenue,
    @JsonKey(name: 'avgTicket') @Default(0) num avgTicket,
    @JsonKey(name: 'avgCycleMs') num? avgCycleMs,
  }) = _TeamReportRow;

  factory TeamReportRow.fromJson(Map<String, dynamic> json) =>
      _$TeamReportRowFromJson(json);
}

/// Rendimento da equipe: linhas por responsável.
@freezed
abstract class TeamReport with _$TeamReport {
  const factory TeamReport({
    @Default(<TeamReportRow>[]) List<TeamReportRow> rows,
  }) = _TeamReport;

  factory TeamReport.fromJson(Map<String, dynamic> json) =>
      _$TeamReportFromJson(json);
}

// ---------------------------------------------------------------------------
// Top produtos/serviços — GET /report/top-items
// ---------------------------------------------------------------------------

/// Linha do top de produtos/serviços.
@freezed
abstract class TopItemRow with _$TopItemRow {
  const factory TopItemRow({
    @Default('') String name,
    @Default('') String kind,
    @JsonKey(name: 'inventoryItemId') String? inventoryItemId,
    @Default(0) num qty,
    @Default(0) num revenue,
    @Default(0) int orders,
  }) = _TopItemRow;

  factory TopItemRow.fromJson(Map<String, dynamic> json) =>
      _$TopItemRowFromJson(json);
}

/// Top de itens: linhas ordenadas por receita.
@freezed
abstract class TopItemsReport with _$TopItemsReport {
  const factory TopItemsReport({
    String? kind,
    @Default(<TopItemRow>[]) List<TopItemRow> rows,
  }) = _TopItemsReport;

  factory TopItemsReport.fromJson(Map<String, dynamic> json) =>
      _$TopItemsReportFromJson(json);
}

// ---------------------------------------------------------------------------
// Estoque (posição) — GET /report/inventory
// ---------------------------------------------------------------------------

/// Linha da posição de estoque.
@freezed
abstract class InventoryReportRow with _$InventoryReportRow {
  const factory InventoryReportRow({
    @Default('') String name,
    String? sku,
    @JsonKey(name: 'current_stock') @Default(0) num currentStock,
    @JsonKey(name: 'min_stock') num? minStock,
    @JsonKey(name: 'cost_price') num? costPrice,
    @JsonKey(name: 'sale_price') num? salePrice,
    @JsonKey(name: 'stockValue') @Default(0) num stockValue,
    @JsonKey(name: 'belowMin') @Default(false) bool belowMin,
  }) = _InventoryReportRow;

  factory InventoryReportRow.fromJson(Map<String, dynamic> json) =>
      _$InventoryReportRowFromJson(json);
}

/// Relatório de posição de estoque PAGINADO: linhas da página + valor total
/// (global, todas as páginas) + metadados do paginador (`total`/`page`/`pageSize`).
@freezed
abstract class InventoryReport with _$InventoryReport {
  const factory InventoryReport({
    @Default(<InventoryReportRow>[]) List<InventoryReportRow> rows,
    @JsonKey(name: 'stockValue') @Default(0) num stockValue,
    @Default(0) int total,
    @Default(1) int page,
    @JsonKey(name: 'pageSize') @Default(50) int pageSize,
  }) = _InventoryReport;

  factory InventoryReport.fromJson(Map<String, dynamic> json) =>
      _$InventoryReportFromJson(json);
}

// ---------------------------------------------------------------------------
// Clientes — GET /report/customers
// ---------------------------------------------------------------------------

/// Linha de cliente (novo no range / ativo).
@freezed
abstract class CustomerReportRow with _$CustomerReportRow {
  const factory CustomerReportRow({
    required String id,
    @Default('') String name,
    @Default('') String type,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _CustomerReportRow;

  factory CustomerReportRow.fromJson(Map<String, dynamic> json) =>
      _$CustomerReportRowFromJson(json);
}

/// Relatório de clientes: novos no range + total ativo.
@freezed
abstract class CustomersReport with _$CustomersReport {
  const factory CustomersReport({
    @Default(<CustomerReportRow>[]) List<CustomerReportRow> rows,
    @Default(0) int active,
    @JsonKey(name: 'newInRange') @Default(0) int newInRange,
  }) = _CustomersReport;

  factory CustomersReport.fromJson(Map<String, dynamic> json) =>
      _$CustomersReportFromJson(json);
}

/// Opção de membro da equipe para o filtro "técnico" dos relatórios de OS.
/// Modelo simples (sem freezed) — só transporta `{ id, name }`.
class ReportMemberOption {
  const ReportMemberOption({required this.id, required this.name});

  final String id;
  final String name;
}
