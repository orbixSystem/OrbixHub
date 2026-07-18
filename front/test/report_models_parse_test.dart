import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/report/domain/report_models.dart';

/// Cada modelo de relatório parseia o JSON do backend (`GET /report/*`),
/// respeitando os snake_case keys (`customer_name`, `current_stock`, …).
void main() {
  test('OsOperationalReport parseia linhas + agregados', () {
    final r = OsOperationalReport.fromJson({
      'rows': [
        {
          'number': 'OS-0001',
          'customer_name': 'Maria',
          'status': 'concluida',
          'assigned_to': null,
          'total': 100.5,
          'opened_at': '2026-06-01T10:00:00.000Z',
          'finished_at': '2026-06-02T10:00:00.000Z',
          'cycleMs': 86400000,
        },
      ],
      'byStatus': {'concluida': 1},
      'byAssignedTo': {
        'João': {'count': 1, 'revenue': 100.5},
      },
    });

    expect(r.rows, hasLength(1));
    expect(r.rows.first.customerName, 'Maria');
    expect(r.rows.first.assignedTo, isNull);
    expect(r.byStatus['concluida'], 1);
    expect(r.byAssignedTo['João']!.revenue, 100.5);
  });

  test('RevenueReport parseia série por dia + por status', () {
    final r = RevenueReport.fromJson({
      'total': 300,
      'avgTicket': 150,
      'byDay': [
        {'day': '2026-06-01', 'revenue': 100, 'count': 1},
        {'day': '2026-06-02', 'revenue': 200, 'count': 2},
      ],
      'byStatus': {
        'entregue': {'count': 3, 'revenue': 300},
      },
    });

    expect(r.total, 300);
    expect(r.avgTicket, 150);
    expect(r.byDay, hasLength(2));
    expect(r.byDay[1].revenue, 200);
    expect(r.byStatus['entregue']!.count, 3);
  });

  test('TeamReport parseia linhas (assignedTo nulo permitido)', () {
    final r = TeamReport.fromJson({
      'rows': [
        {
          'assignedTo': null,
          'orders': 2,
          'completed': 1,
          'revenue': 50,
          'avgTicket': 25,
          'avgCycleMs': null,
        },
      ],
    });

    expect(r.rows.first.assignedTo, isNull);
    expect(r.rows.first.orders, 2);
    expect(r.rows.first.avgCycleMs, isNull);
  });

  test('TopItemsReport parseia linhas', () {
    final r = TopItemsReport.fromJson({
      'kind': 'product',
      'rows': [
        {
          'name': 'Óleo',
          'kind': 'product',
          'inventoryItemId': 'i1',
          'qty': 10,
          'revenue': 500,
          'orders': 5,
        },
      ],
    });

    expect(r.kind, 'product');
    expect(r.rows.first.name, 'Óleo');
    expect(r.rows.first.qty, 10);
  });

  test('InventoryReport parseia posição + valor total', () {
    final r = InventoryReport.fromJson({
      'stockValue': 250,
      'rows': [
        {
          'name': 'Filtro',
          'sku': 'F1',
          'current_stock': 2,
          'min_stock': 8,
          'cost_price': 15,
          'sale_price': 35,
          'stockValue': 30,
          'belowMin': true,
        },
      ],
    });

    expect(r.stockValue, 250);
    expect(r.rows.first.currentStock, 2);
    expect(r.rows.first.belowMin, isTrue);
  });

  test('CustomersReport parseia novos + ativos + paginação + série', () {
    final r = CustomersReport.fromJson({
      'active': 42,
      'newInRange': 3,
      'total': 3,
      'page': 1,
      'pageSize': 50,
      'rows': [
        {
          'id': 'c1',
          'name': 'Maria',
          'type': 'pf',
          'created_at': '2026-06-03T12:00:00.000Z',
        },
      ],
      'series': [
        {'day': '2026-06-03', 'type': 'pf', 'count': 2},
        {'day': '2026-06-04', 'type': 'pj', 'count': 1},
      ],
    });

    expect(r.active, 42);
    expect(r.newInRange, 3);
    expect(r.total, 3);
    expect(r.page, 1);
    expect(r.pageSize, 50);
    expect(r.rows.first.name, 'Maria');
    expect(r.series, hasLength(2));
    expect(r.series.first.day, '2026-06-03');
    expect(r.series.first.type, 'pf');
    expect(r.series.first.count, 2);
  });

  test('CustomersReport tolera resposta sem paginação/série (defaults)', () {
    final r = CustomersReport.fromJson({
      'active': 1,
      'newInRange': 0,
      'rows': [],
    });

    expect(r.total, 0);
    expect(r.page, 1);
    expect(r.pageSize, 50);
    expect(r.series, isEmpty);
  });
}
