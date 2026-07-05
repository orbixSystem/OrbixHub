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
    <String, dynamic>{'rows': instance.rows};

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
  'rows': instance.rows,
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
  'byStatus': instance.byStatus,
  'byAssignedTo': instance.byAssignedTo,
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
      'byDay': instance.byDay,
      'byStatus': instance.byStatus,
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
    <String, dynamic>{'rows': instance.rows};

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
    <String, dynamic>{'kind': instance.kind, 'rows': instance.rows};

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
      'rows': instance.rows,
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

_CustomersReport _$CustomersReportFromJson(Map<String, dynamic> json) =>
    _CustomersReport(
      rows:
          (json['rows'] as List<dynamic>?)
              ?.map(
                (e) => CustomerReportRow.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <CustomerReportRow>[],
      active: (json['active'] as num?)?.toInt() ?? 0,
      newInRange: (json['newInRange'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CustomersReportToJson(_CustomersReport instance) =>
    <String, dynamic>{
      'rows': instance.rows,
      'active': instance.active,
      'newInRange': instance.newInRange,
    };
