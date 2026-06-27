import 'dashboard_models.dart';

/// Contrato da camada de métricas do dashboard. Cada método bate no endpoint
/// `/metrics` do módulo dono (regra "aponta, não invade": o dado agregado nasce
/// no módulo). Gating real (módulo + permissão) é do backend; a UI só reflete.
/// A UI nunca fala com o dio direto — sempre via este repository.
abstract interface class DashboardRepository {
  /// Métricas de OS. `assignedTo` restringe a "minhas OS" (visão operacional do
  /// mecânico); ausente = visão gerencial (todas as OS do tenant).
  Future<OsMetrics> osMetrics({
    required MetricsRange range,
    String? assignedTo,
  });

  /// Métricas de estoque — point-in-time (ignora o período).
  Future<InventoryMetrics> inventoryMetrics();

  /// Métricas de clientes no período.
  Future<CustomersMetrics> customersMetrics({required MetricsRange range});
}
