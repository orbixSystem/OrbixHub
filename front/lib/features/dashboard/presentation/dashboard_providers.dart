import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';
import 'period_controller.dart';

/// Injetado em `di.dart` com a impl real (dio). Tests sobrescrevem com o fake.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  throw UnimplementedError(
      'dashboardRepositoryProvider must be overridden in di.dart');
});

/// Id do usuário logado (para a visão "minhas OS" do mecânico). Null se não
/// autenticado.
final _currentUserIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session is SessionAuthenticated ? session.me.user.id : null;
});

/// OS — visão gerencial (todas as OS). Reage ao período. autoDispose: re-busca
/// ao reentrar / trocar de período.
final osManagementMetricsProvider =
    FutureProvider.autoDispose<OsMetrics>((ref) {
  final range = ref.watch(metricsRangeProvider);
  return ref.read(dashboardRepositoryProvider).osMetrics(range: range);
});

/// OS — visão operacional ("minhas OS"): passa `assignedTo = me.user.id`.
final osOperationalMetricsProvider =
    FutureProvider.autoDispose<OsMetrics>((ref) {
  final range = ref.watch(metricsRangeProvider);
  final userId = ref.watch(_currentUserIdProvider);
  return ref
      .read(dashboardRepositoryProvider)
      .osMetrics(range: range, assignedTo: userId);
});

/// Estoque — point-in-time (ignora o período).
final inventoryMetricsProvider =
    FutureProvider.autoDispose<InventoryMetrics>((ref) {
  return ref.read(dashboardRepositoryProvider).inventoryMetrics();
});

/// Clientes — reage ao período.
final customersMetricsProvider =
    FutureProvider.autoDispose<CustomersMetrics>((ref) {
  final range = ref.watch(metricsRangeProvider);
  return ref.read(dashboardRepositoryProvider).customersMetrics(range: range);
});
