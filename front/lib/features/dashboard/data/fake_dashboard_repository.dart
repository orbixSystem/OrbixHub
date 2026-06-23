import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';

/// [DashboardRepository] em memória, com números realistas, para testes/offline.
/// A visão "minhas OS" (quando `assignedTo` é passado) devolve um subconjunto
/// menor, espelhando o comportamento do backend.
class FakeDashboardRepository implements DashboardRepository {
  const FakeDashboardRepository();

  @override
  Future<OsMetrics> osMetrics({
    required MetricsRange range,
    String? assignedTo,
  }) async {
    if (assignedTo != null && assignedTo.isNotEmpty) {
      // Visão operacional: só as OS do técnico.
      return const OsMetrics(
        byStatus: {'aberta': 2, 'em_execucao': 3, 'concluida': 4},
        revenue: 0,
        avgTicket: 0,
        inExecution: 3,
        overdue: 1,
        avgCycleMs: 9 * 60 * 60 * 1000, // 9h
      );
    }
    // Visão gerencial: todas as OS do tenant.
    return const OsMetrics(
      byStatus: {
        'aberta': 5,
        'em_execucao': 7,
        'concluida': 18,
        'entregue': 12,
        'cancelada': 2,
      },
      revenue: 48750.50,
      avgTicket: 1625.02,
      inExecution: 7,
      overdue: 3,
      avgCycleMs: 2 * 24 * 60 * 60 * 1000, // 2 dias
    );
  }

  @override
  Future<InventoryMetrics> inventoryMetrics() async {
    return const InventoryMetrics(
      belowMin: 3,
      stockValue: 18250.75,
      products: 142,
      services: 27,
      lowStockSample: [
        LowStockItem(
          id: 'i1',
          name: 'Óleo 5W30',
          sku: 'OL-5W30',
          currentStock: '2',
          minStock: '10',
        ),
        LowStockItem(
          id: 'i2',
          name: 'Filtro de ar',
          sku: 'FL-AR-01',
          currentStock: '1',
          minStock: '5',
        ),
        LowStockItem(
          id: 'i3',
          name: 'Pastilha de freio',
          sku: 'PF-220',
          currentStock: '4',
          minStock: '8',
        ),
      ],
    );
  }

  @override
  Future<CustomersMetrics> customersMetrics({
    required MetricsRange range,
  }) async {
    return const CustomersMetrics(active: 86, newInRange: 9);
  }
}
