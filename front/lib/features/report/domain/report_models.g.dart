// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SalesLedgerRow _$SalesLedgerRowFromJson(Map<String, dynamic> json) =>
    _SalesLedgerRow(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      type: json['type'] as String? ?? 'servico',
      origin: json['origin'] as String? ?? 'os',
      originNumber: json['originNumber'] as String? ?? '',
      customerName: json['customerName'] as String?,
      value: json['value'] as num? ?? 0,
      paymentStatus: json['paymentStatus'] as String? ?? 'a_receber',
    );

Map<String, dynamic> _$SalesLedgerRowToJson(_SalesLedgerRow instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date,
      'type': instance.type,
      'origin': instance.origin,
      'originNumber': instance.originNumber,
      'customerName': instance.customerName,
      'value': instance.value,
      'paymentStatus': instance.paymentStatus,
    };

_SalesLedger _$SalesLedgerFromJson(Map<String, dynamic> json) => _SalesLedger(
  rows:
      (json['rows'] as List<dynamic>?)
          ?.map((e) => SalesLedgerRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SalesLedgerRow>[],
);

Map<String, dynamic> _$SalesLedgerToJson(_SalesLedger instance) =>
    <String, dynamic>{'rows': instance.rows.map((e) => e.toJson()).toList()};

_OsReportRow _$OsReportRowFromJson(Map<String, dynamic> json) => _OsReportRow(
  number: json['number'] as String,
  customerName: json['customer_name'] as String? ?? '',
  status: json['status'] as String? ?? '',
  assignedTo: json['assigned_to'] as String?,
  total: json['total'] as num? ?? 0,
  openedAt: json['opened_at'] as String?,
  finishedAt: json['finished_at'] as String?,
  cycleMs: json['cycleMs'] as num?,
);

Map<String, dynamic> _$OsReportRowToJson(_OsReportRow instance) =>
    <String, dynamic>{
      'number': instance.number,
      'customer_name': instance.customerName,
      'status': instance.status,
      'assigned_to': instance.assignedTo,
      'total': instance.total,
      'opened_at': instance.openedAt,
      'finished_at': instance.finishedAt,
      'cycleMs': instance.cycleMs,
    };

_CountRevenue _$CountRevenueFromJson(Map<String, dynamic> json) =>
    _CountRevenue(
      count: (json['count'] as num?)?.toInt() ?? 0,
      revenue: json['revenue'] as num? ?? 0,
    );

Map<String, dynamic> _$CountRevenueToJson(_CountRevenue instance) =>
    <String, dynamic>{'count': instance.count, 'revenue': instance.revenue};

_OsOperationalReport _$OsOperationalReportFromJson(Map<String, dynamic> json) =>
    _OsOperationalReport(
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map((e) => OsReportRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <OsReportRow>[],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 50,
      byStatus:
          (json['byStatus'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      byAssignedTo:
          (json['byAssignedTo'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, CountRevenue.fromJson(e as Map<String, dynamic>)),
          ) ??
          const <String, CountRevenue>{},
    );

Map<String, dynamic> _$OsOperationalReportToJson(
  _OsOperationalReport instance,
) => <String, dynamic>{
  'rows': instance.rows.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
  'byStatus': instance.byStatus,
  'byAssignedTo': instance.byAssignedTo.map((k, e) => MapEntry(k, e.toJson())),
};

_RevenueByDay _$RevenueByDayFromJson(Map<String, dynamic> json) =>
    _RevenueByDay(
      day: json['day'] as String? ?? '',
      revenue: json['revenue'] as num? ?? 0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RevenueByDayToJson(_RevenueByDay instance) =>
    <String, dynamic>{
      'day': instance.day,
      'revenue': instance.revenue,
      'count': instance.count,
    };

_RevenueReport _$RevenueReportFromJson(Map<String, dynamic> json) =>
    _RevenueReport(
      total: json['total'] as num? ?? 0,
      avgTicket: json['avgTicket'] as num? ?? 0,
      byDay:
          (json['byDay'] as List<dynamic>?)
              ?.map((e) => RevenueByDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RevenueByDay>[],
      byStatus:
          (json['byStatus'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, CountRevenue.fromJson(e as Map<String, dynamic>)),
          ) ??
          const <String, CountRevenue>{},
    );

Map<String, dynamic> _$RevenueReportToJson(_RevenueReport instance) =>
    <String, dynamic>{
      'total': instance.total,
      'avgTicket': instance.avgTicket,
      'byDay': instance.byDay.map((e) => e.toJson()).toList(),
      'byStatus': instance.byStatus.map((k, e) => MapEntry(k, e.toJson())),
    };

_TeamReportRow _$TeamReportRowFromJson(Map<String, dynamic> json) =>
    _TeamReportRow(
      assignedTo: json['assignedTo'] as String?,
      orders: (json['orders'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      revenue: json['revenue'] as num? ?? 0,
      avgTicket: json['avgTicket'] as num? ?? 0,
      avgCycleMs: json['avgCycleMs'] as num?,
    );

Map<String, dynamic> _$TeamReportRowToJson(_TeamReportRow instance) =>
    <String, dynamic>{
      'assignedTo': instance.assignedTo,
      'orders': instance.orders,
      'completed': instance.completed,
      'revenue': instance.revenue,
      'avgTicket': instance.avgTicket,
      'avgCycleMs': instance.avgCycleMs,
    };

_TeamReport _$TeamReportFromJson(Map<String, dynamic> json) => _TeamReport(
  rows:
      (json['rows'] as List<dynamic>?)
          ?.map((e) => TeamReportRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TeamReportRow>[],
);

Map<String, dynamic> _$TeamReportToJson(_TeamReport instance) =>
    <String, dynamic>{'rows': instance.rows.map((e) => e.toJson()).toList()};

_TopItemRow _$TopItemRowFromJson(Map<String, dynamic> json) => _TopItemRow(
  name: json['name'] as String? ?? '',
  kind: json['kind'] as String? ?? '',
  inventoryItemId: json['inventoryItemId'] as String?,
  qty: json['qty'] as num? ?? 0,
  revenue: json['revenue'] as num? ?? 0,
  orders: (json['orders'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TopItemRowToJson(_TopItemRow instance) =>
    <String, dynamic>{
      'name': instance.name,
      'kind': instance.kind,
      'inventoryItemId': instance.inventoryItemId,
      'qty': instance.qty,
      'revenue': instance.revenue,
      'orders': instance.orders,
    };

_TopItemsReport _$TopItemsReportFromJson(Map<String, dynamic> json) =>
    _TopItemsReport(
      kind: json['kind'] as String?,
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map((e) => TopItemRow.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <TopItemRow>[],
    );

Map<String, dynamic> _$TopItemsReportToJson(_TopItemsReport instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'rows': instance.rows.map((e) => e.toJson()).toList(),
    };

_InventoryReportRow _$InventoryReportRowFromJson(Map<String, dynamic> json) =>
    _InventoryReportRow(
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      currentStock: json['current_stock'] as num? ?? 0,
      minStock: json['min_stock'] as num?,
      costPrice: json['cost_price'] as num?,
      salePrice: json['sale_price'] as num?,
      stockValue: json['stockValue'] as num? ?? 0,
      belowMin: json['belowMin'] as bool? ?? false,
    );

Map<String, dynamic> _$InventoryReportRowToJson(_InventoryReportRow instance) =>
    <String, dynamic>{
      'name': instance.name,
      'sku': instance.sku,
      'current_stock': instance.currentStock,
      'min_stock': instance.minStock,
      'cost_price': instance.costPrice,
      'sale_price': instance.salePrice,
      'stockValue': instance.stockValue,
      'belowMin': instance.belowMin,
    };

_InventoryReport _$InventoryReportFromJson(Map<String, dynamic> json) =>
    _InventoryReport(
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map(
                (e) => InventoryReportRow.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <InventoryReportRow>[],
      stockValue: json['stockValue'] as num? ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 50,
    );

Map<String, dynamic> _$InventoryReportToJson(_InventoryReport instance) =>
    <String, dynamic>{
      'rows': instance.rows.map((e) => e.toJson()).toList(),
      'stockValue': instance.stockValue,
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

_CustomerReportRow _$CustomerReportRowFromJson(Map<String, dynamic> json) =>
    _CustomerReportRow(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$CustomerReportRowToJson(_CustomerReportRow instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'created_at': instance.createdAt,
    };

_CustomersSeriesPoint _$CustomersSeriesPointFromJson(
  Map<String, dynamic> json,
) => _CustomersSeriesPoint(
  day: json['day'] as String? ?? '',
  type: json['type'] as String? ?? '',
  count: (json['count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CustomersSeriesPointToJson(
  _CustomersSeriesPoint instance,
) => <String, dynamic>{
  'day': instance.day,
  'type': instance.type,
  'count': instance.count,
};

_CustomersReport _$CustomersReportFromJson(
  Map<String, dynamic> json,
) => _CustomersReport(
  rows:
      (json['rows'] as List<dynamic>?)
          ?.map((e) => CustomerReportRow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CustomerReportRow>[],
  active: (json['active'] as num?)?.toInt() ?? 0,
  newInRange: (json['newInRange'] as num?)?.toInt() ?? 0,
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 50,
  series:
      (json['series'] as List<dynamic>?)
          ?.map((e) => CustomersSeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <CustomersSeriesPoint>[],
);

Map<String, dynamic> _$CustomersReportToJson(_CustomersReport instance) =>
    <String, dynamic>{
      'rows': instance.rows.map((e) => e.toJson()).toList(),
      'active': instance.active,
      'newInRange': instance.newInRange,
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
      'series': instance.series.map((e) => e.toJson()).toList(),
    };

_ExpenseCategoryReportRow _$ExpenseCategoryReportRowFromJson(
  Map<String, dynamic> json,
) => _ExpenseCategoryReportRow(
  categoryId: json['categoryId'] as String?,
  categoryName: json['categoryName'] as String? ?? '',
  categoryColor: json['categoryColor'] as String?,
  count: (json['count'] as num?)?.toInt() ?? 0,
  previsto: json['previsto'] as num? ?? 0,
  pago: json['pago'] as num? ?? 0,
  emAberto: json['emAberto'] as num? ?? 0,
  vencido: json['vencido'] as num? ?? 0,
);

Map<String, dynamic> _$ExpenseCategoryReportRowToJson(
  _ExpenseCategoryReportRow instance,
) => <String, dynamic>{
  'categoryId': instance.categoryId,
  'categoryName': instance.categoryName,
  'categoryColor': instance.categoryColor,
  'count': instance.count,
  'previsto': instance.previsto,
  'pago': instance.pago,
  'emAberto': instance.emAberto,
  'vencido': instance.vencido,
};

_ExpensesReportTotals _$ExpensesReportTotalsFromJson(
  Map<String, dynamic> json,
) => _ExpensesReportTotals(
  count: (json['count'] as num?)?.toInt() ?? 0,
  previsto: json['previsto'] as num? ?? 0,
  pago: json['pago'] as num? ?? 0,
  emAberto: json['emAberto'] as num? ?? 0,
  vencido: json['vencido'] as num? ?? 0,
);

Map<String, dynamic> _$ExpensesReportTotalsToJson(
  _ExpensesReportTotals instance,
) => <String, dynamic>{
  'count': instance.count,
  'previsto': instance.previsto,
  'pago': instance.pago,
  'emAberto': instance.emAberto,
  'vencido': instance.vencido,
};

_ExpensesReport _$ExpensesReportFromJson(
  Map<String, dynamic> json,
) => _ExpensesReport(
  rows:
      (json['rows'] as List<dynamic>?)
          ?.map(
            (e) => ExpenseCategoryReportRow.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <ExpenseCategoryReportRow>[],
  totals: json['totals'] == null
      ? const ExpensesReportTotals()
      : ExpensesReportTotals.fromJson(json['totals'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ExpensesReportToJson(_ExpensesReport instance) =>
    <String, dynamic>{
      'rows': instance.rows.map((e) => e.toJson()).toList(),
      'totals': instance.totals.toJson(),
    };

_ClienteRanqueado _$ClienteRanqueadoFromJson(Map<String, dynamic> json) =>
    _ClienteRanqueado(
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Cliente',
      recebido: json['recebido'] as num? ?? 0,
      desconto: json['desconto'] as num? ?? 0,
      atendimentos: (json['atendimentos'] as num?)?.toInt() ?? 0,
      osCount: (json['osCount'] as num?)?.toInt() ?? 0,
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      ticketMedio: json['ticketMedio'] as num? ?? 0,
      primeiroEm: json['primeiroEm'] as String? ?? '',
      ultimoEm: json['ultimoEm'] as String? ?? '',
    );

Map<String, dynamic> _$ClienteRanqueadoToJson(_ClienteRanqueado instance) =>
    <String, dynamic>{
      'customerId': instance.customerId,
      'customerName': instance.customerName,
      'recebido': instance.recebido,
      'desconto': instance.desconto,
      'atendimentos': instance.atendimentos,
      'osCount': instance.osCount,
      'saleCount': instance.saleCount,
      'ticketMedio': instance.ticketMedio,
      'primeiroEm': instance.primeiroEm,
      'ultimoEm': instance.ultimoEm,
    };

_CustomersRanking _$CustomersRankingFromJson(Map<String, dynamic> json) =>
    _CustomersRanking(
      porReceita:
          (json['porReceita'] as List<dynamic>?)
              ?.map((e) => ClienteRanqueado.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ClienteRanqueado>[],
      porRecorrencia:
          (json['porRecorrencia'] as List<dynamic>?)
              ?.map((e) => ClienteRanqueado.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <ClienteRanqueado>[],
      totalClientes: (json['totalClientes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CustomersRankingToJson(_CustomersRanking instance) =>
    <String, dynamic>{
      'porReceita': instance.porReceita.map((e) => e.toJson()).toList(),
      'porRecorrencia': instance.porRecorrencia.map((e) => e.toJson()).toList(),
      'totalClientes': instance.totalClientes,
    };
