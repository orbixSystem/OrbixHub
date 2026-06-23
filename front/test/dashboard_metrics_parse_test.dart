import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/dashboard/domain/dashboard_models.dart';

/// Fixa o contrato dos endpoints `/metrics` (Fase 1) → models. snake_case via
/// @JsonKey; campos ausentes/nulos com defaults seguros.
void main() {
  test('parses /os/metrics', () {
    final m = OsMetrics.fromJson({
      'range': {'from': '2026-06-01', 'to': '2026-06-22'},
      'byStatus': {'aberta': 5, 'em_execucao': 7, 'concluida': 18},
      'revenue': 48750.5,
      'avgTicket': 1625.02,
      'inExecution': 7,
      'overdue': 3,
      'avgCycleMs': 172800000,
    });

    expect(m.byStatus['em_execucao'], 7);
    expect(m.totalOrders, 30);
    expect(m.revenue, 48750.5);
    expect(m.avgTicket, 1625.02);
    expect(m.inExecution, 7);
    expect(m.overdue, 3);
    expect(m.avgCycleMs, 172800000);
  });

  test('parses /os/metrics with null avgCycleMs and empty status', () {
    final m = OsMetrics.fromJson({
      'byStatus': <String, dynamic>{},
      'revenue': 0,
      'avgTicket': 0,
      'inExecution': 0,
      'overdue': 0,
      'avgCycleMs': null,
    });
    expect(m.avgCycleMs, isNull);
    expect(m.totalOrders, 0);
  });

  test('parses /inventory/metrics with NUMERIC current/min stock', () {
    // O backend (`GET /inventory/metrics`) devolve current_stock/min_stock como
    // NÚMEROS, não strings. Regressão: antes o model tipava como String e o
    // parsing estourava quando havia itens abaixo do mínimo.
    final m = InventoryMetrics.fromJson({
      'belowMin': 3,
      'stockValue': 18250.75,
      'products': 142,
      'services': 27,
      'lowStockSample': [
        {
          'id': 'i1',
          'name': 'Óleo 5W30',
          'sku': 'OL-5W30',
          'current_stock': 5,
          'min_stock': 10,
        },
      ],
    });

    expect(m.belowMin, 3);
    expect(m.stockValue, 18250.75);
    expect(m.products, 142);
    expect(m.services, 27);
    expect(m.lowStockSample, hasLength(1));
    expect(m.lowStockSample.first.currentStock, 5);
    expect(m.lowStockSample.first.minStock, 10);
  });

  test('LowStockItem aceita current/min stock fracionário e ausente', () {
    final item = LowStockItem.fromJson({
      'id': 'i2',
      'name': 'Cabo',
      'current_stock': 2.5,
      // min_stock ausente → null
    });
    expect(item.currentStock, 2.5);
    expect(item.minStock, isNull);
  });

  test('parses /customers/metrics', () {
    final m = CustomersMetrics.fromJson({
      'range': {'from': '2026-06-01', 'to': '2026-06-22'},
      'active': 86,
      'newInRange': 9,
    });
    expect(m.active, 86);
    expect(m.newInRange, 9);
  });
}
