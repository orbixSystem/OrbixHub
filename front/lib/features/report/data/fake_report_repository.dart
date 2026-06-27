import 'dart:convert';
import 'dart:typed_data';

import '../domain/report_models.dart';
import '../domain/report_repository.dart';

/// [ReportRepository] falso com linhas realistas. Usado em testes/dev (sem rede).
class FakeReportRepository implements ReportRepository {
  static const _osRows = <OsReportRow>[
    OsReportRow(
      number: 'OS-0001',
      customerName: 'Maria Silva',
      status: 'concluida',
      assignedTo: 'João Mecânico',
      total: 450.90,
      openedAt: '2026-06-01T10:00:00.000Z',
      finishedAt: '2026-06-02T14:00:00.000Z',
      cycleMs: 100800000,
    ),
    OsReportRow(
      number: 'OS-0002',
      customerName: 'Auto Center LTDA',
      status: 'em_execucao',
      assignedTo: null,
      total: 1280.00,
      openedAt: '2026-06-05T09:30:00.000Z',
    ),
  ];

  @override
  Future<OsOperationalReport> osReport({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
    int page = 1,
    int pageSize = 50,
  }) async {
    final filtered = (q == null || q.isEmpty)
        ? _osRows
        : _osRows
            .where((o) =>
                o.number.toLowerCase().contains(q.toLowerCase()) ||
                o.customerName.toLowerCase().contains(q.toLowerCase()))
            .toList();
    final start = (page - 1) * pageSize;
    final slice = start >= filtered.length
        ? const <OsReportRow>[]
        : filtered.sublist(
            start,
            (start + pageSize).clamp(0, filtered.length),
          );
    return OsOperationalReport(
      rows: slice,
      total: filtered.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<RevenueReport> revenue({required ReportRange range}) async =>
      const RevenueReport(
        total: 1730.90,
        avgTicket: 865.45,
        byDay: [
          RevenueByDay(day: '2026-06-01', revenue: 450.90, count: 1),
          RevenueByDay(day: '2026-06-02', revenue: 1280.00, count: 1),
        ],
        byStatus: {
          'concluida': CountRevenue(count: 1, revenue: 450.90),
          'entregue': CountRevenue(count: 1, revenue: 1280.00),
        },
      );

  @override
  Future<TeamReport> team({required ReportRange range}) async => const TeamReport(
        rows: [
          TeamReportRow(
            assignedTo: 'João Mecânico',
            orders: 4,
            completed: 3,
            revenue: 3200.00,
            avgTicket: 800.00,
            avgCycleMs: 86400000,
          ),
          TeamReportRow(
            assignedTo: null,
            orders: 2,
            completed: 1,
            revenue: 600.00,
            avgTicket: 300.00,
            avgCycleMs: null,
          ),
        ],
      );

  @override
  Future<TopItemsReport> topItems({
    required ReportRange range,
    String? kind,
    int? limit,
  }) async =>
      const TopItemsReport(
        kind: null,
        rows: [
          TopItemRow(
            name: 'Óleo 5W30',
            kind: 'product',
            qty: 24,
            revenue: 1200.00,
            orders: 12,
          ),
          TopItemRow(
            name: 'Troca de óleo',
            kind: 'service',
            qty: 12,
            revenue: 600.00,
            orders: 12,
          ),
        ],
      );

  static const _inventoryRows = <InventoryReportRow>[
    InventoryReportRow(
      name: 'Óleo 5W30',
      sku: 'OL-5W30',
      currentStock: 10,
      minStock: 5,
      costPrice: 25.00,
      salePrice: 50.00,
      stockValue: 250.00,
      belowMin: false,
    ),
    InventoryReportRow(
      name: 'Filtro de ar',
      sku: 'FA-001',
      currentStock: 2,
      minStock: 8,
      costPrice: 15.00,
      salePrice: 35.00,
      stockValue: 30.00,
      belowMin: true,
    ),
  ];

  @override
  Future<InventoryReport> inventory({
    int page = 1,
    int pageSize = 50,
    String? q,
  }) async {
    final start = (page - 1) * pageSize;
    final slice = start >= _inventoryRows.length
        ? const <InventoryReportRow>[]
        : _inventoryRows.sublist(
            start,
            (start + pageSize).clamp(0, _inventoryRows.length),
          );
    return InventoryReport(
      stockValue: 8500.00,
      rows: slice,
      total: _inventoryRows.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Uint8List> inventoryCsv({String? q}) async =>
      Uint8List.fromList(utf8.encode('Item;Valor\r\nÓleo 5W30;250,00\r\n'));

  @override
  Future<Uint8List> inventoryPdf({
    ReportExportCompany? company,
    String? q,
  }) async =>
      Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]); // "%PDF"

  @override
  Future<CustomersReport> customers({required ReportRange range}) async =>
      const CustomersReport(
        active: 42,
        newInRange: 3,
        rows: [
          CustomerReportRow(
            id: 'c1',
            name: 'Maria Silva',
            type: 'pf',
            createdAt: '2026-06-03T12:00:00.000Z',
          ),
          CustomerReportRow(
            id: 'c2',
            name: 'Auto Center LTDA',
            type: 'pj',
            createdAt: '2026-06-10T08:00:00.000Z',
          ),
        ],
      );

  @override
  Future<List<ReportMemberOption>> members() async => const [
        ReportMemberOption(id: 'm1', name: 'João Mecânico'),
        ReportMemberOption(id: 'm2', name: 'Ana Atendente'),
      ];
}
