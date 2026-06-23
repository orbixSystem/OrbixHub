import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Filtros contextuais dos relatórios de OS.
class ReportFilters {
  const ReportFilters({
    this.assignedTo,
    this.status,
    this.kind,
    this.limit = 10,
  });

  /// Técnico (uuid do membro) — OS operacional.
  final String? assignedTo;

  /// Status da OS — OS operacional.
  final String? status;

  /// Tipo (product/service) — top-itens.
  final String? kind;

  /// Top N — top-itens.
  final int limit;

  ReportFilters copyWith({
    String? assignedTo,
    bool clearAssignedTo = false,
    String? status,
    bool clearStatus = false,
    String? kind,
    bool clearKind = false,
    int? limit,
  }) =>
      ReportFilters(
        assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
        status: clearStatus ? null : (status ?? this.status),
        kind: clearKind ? null : (kind ?? this.kind),
        limit: limit ?? this.limit,
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
}

/// Membros da equipe (para o filtro "técnico"). autoDispose: re-busca ao reentrar.
final reportMembersProvider =
    FutureProvider.autoDispose<List<ReportMemberOption>>((ref) {
  return ref.read(reportRepositoryProvider).members();
});

// --- Providers de dados, um por relatório. Reagem a período + filtros. ---

final osOperationalReportProvider =
    FutureProvider.autoDispose<OsOperationalReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  final filters = ref.watch(reportFiltersProvider);
  return ref.read(reportRepositoryProvider).osReport(
        range: range,
        assignedTo: filters.assignedTo,
        status: filters.status,
      );
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

final inventoryReportProvider =
    FutureProvider.autoDispose<InventoryReport>((ref) {
  return ref.read(reportRepositoryProvider).inventory();
});

final customersReportProvider =
    FutureProvider.autoDispose<CustomersReport>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.read(reportRepositoryProvider).customers(range: range);
});
