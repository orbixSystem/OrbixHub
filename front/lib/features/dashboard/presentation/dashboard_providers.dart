import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di.dart';
import '../../auth/presentation/session_state.dart';
import '../../os/domain/os_models.dart';
import '../../os/presentation/os_providers.dart';
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
  return session.meOrNull?.user.id;
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

/// OS em andamento para o painel da Home: até 5 OS mais recentes em
/// `em_execucao`, já com o nome do responsável resolvido (`assigned_to` → nome
/// do membro via `listMembers`, serviço público — "aponta, não invade").
/// Reusa o `OsRepository` (sem endpoint novo). autoDispose: re-busca ao reentrar.
///
/// [assignedTo] (opcional): quando informado, filtra só as OS desse responsável
/// (visão operacional do mecânico — "minhas OS"). Null = todas (gerencial).
final activeOrdersProvider = FutureProvider.autoDispose
    .family<List<ActiveOrder>, String?>((ref, assignedTo) async {
  final repo = ref.read(osRepositoryProvider);
  final page = await repo.listOrders(status: 'em_execucao');
  var orders = page.items;
  if (assignedTo != null) {
    orders = orders.where((o) => o.assignedTo == assignedTo).toList();
  }
  orders = orders.take(5).toList();
  // Mapa id→nome do responsável (best-effort; falha vira "—").
  Map<String, String> names = const {};
  try {
    final members = await repo.listMembers();
    names = {for (final m in members) m.id: m.name};
  } catch (_) {
    names = const {};
  }
  return [
    for (final o in orders)
      ActiveOrder(
        order: o,
        assigneeName: o.assignedTo == null ? null : names[o.assignedTo],
      ),
  ];
});

/// "Minhas OS atrasadas": OS do responsável [assignedTo] cujo `scheduled_end` já
/// passou e que não estão concluída/entregue/cancelada. Sinal operacional simples
/// (contagem); reusa a lista de OS e filtra no cliente. autoDispose.
final myOverdueOrdersProvider = FutureProvider.autoDispose
    .family<List<ServiceOrder>, String?>((ref, assignedTo) async {
  if (assignedTo == null) return const <ServiceOrder>[];
  final repo = ref.read(osRepositoryProvider);
  final page = await repo.listOrders();
  final now = DateTime.now();
  const done = {'concluida', 'entregue', 'cancelada'};
  return page.items.where((o) {
    if (o.assignedTo != assignedTo) return false;
    if (done.contains(o.status)) return false;
    final end = o.scheduledEnd == null
        ? null
        : DateTime.tryParse(o.scheduledEnd!);
    return end != null && end.isBefore(now);
  }).toList();
});

/// Uma OS em execução + o nome do responsável já resolvido (para o painel).
class ActiveOrder {
  const ActiveOrder({required this.order, this.assigneeName});
  final ServiceOrder order;
  final String? assigneeName;
}
