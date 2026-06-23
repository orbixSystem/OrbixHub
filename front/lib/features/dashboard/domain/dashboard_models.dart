import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_models.freezed.dart';
part 'dashboard_models.g.dart';

/// Janela de tempo resolvida no front e enviada como `?from=ISO&to=ISO`.
class MetricsRange {
  const MetricsRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  String get fromIso => from.toUtc().toIso8601String();
  String get toIso => to.toUtc().toIso8601String();
}

/// Métricas de OS (`GET /os/metrics`). Visão gerencial (todas as OS) ou
/// operacional ("minhas OS", via `assignedTo`). `byStatus` mapeia status→contagem.
/// `avgCycleMs` é nulo quando ainda não há OS concluída no período.
@freezed
abstract class OsMetrics with _$OsMetrics {
  const OsMetrics._();

  const factory OsMetrics({
    @Default(<String, int>{}) Map<String, int> byStatus,
    @Default(0) num revenue,
    @JsonKey(name: 'avgTicket') @Default(0) num avgTicket,
    @Default(0) int inExecution,
    @Default(0) int overdue,
    @JsonKey(name: 'avgCycleMs') num? avgCycleMs,
  }) = _OsMetrics;

  factory OsMetrics.fromJson(Map<String, dynamic> json) =>
      _$OsMetricsFromJson(json);

  /// Total de OS no período (soma de todos os status).
  int get totalOrders => byStatus.values.fold(0, (a, b) => a + b);
}

/// Uma linha da amostra de itens abaixo do mínimo (`lowStockSample`).
@freezed
abstract class LowStockItem with _$LowStockItem {
  const factory LowStockItem({
    required String id,
    required String name,
    String? sku,
    @JsonKey(name: 'current_stock') @Default('0') String currentStock,
    @JsonKey(name: 'min_stock') String? minStock,
  }) = _LowStockItem;

  factory LowStockItem.fromJson(Map<String, dynamic> json) =>
      _$LowStockItemFromJson(json);
}

/// Métricas de estoque (`GET /inventory/metrics`). Point-in-time (ignora período).
@freezed
abstract class InventoryMetrics with _$InventoryMetrics {
  const factory InventoryMetrics({
    @Default(0) int belowMin,
    @JsonKey(name: 'stockValue') @Default(0) num stockValue,
    @Default(0) int products,
    @Default(0) int services,
    @JsonKey(name: 'lowStockSample')
    @Default(<LowStockItem>[])
    List<LowStockItem> lowStockSample,
  }) = _InventoryMetrics;

  factory InventoryMetrics.fromJson(Map<String, dynamic> json) =>
      _$InventoryMetricsFromJson(json);
}

/// Métricas de clientes (`GET /customers/metrics`).
@freezed
abstract class CustomersMetrics with _$CustomersMetrics {
  const factory CustomersMetrics({
    @Default(0) int active,
    @JsonKey(name: 'newInRange') @Default(0) int newInRange,
  }) = _CustomersMetrics;

  factory CustomersMetrics.fromJson(Map<String, dynamic> json) =>
      _$CustomersMetricsFromJson(json);
}
