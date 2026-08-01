// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OsMetrics _$OsMetricsFromJson(Map<String, dynamic> json) => _OsMetrics(
  byStatus:
      (json['byStatus'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const <String, int>{},
  revenue: json['revenue'] as num? ?? 0,
  avgTicket: json['avgTicket'] as num? ?? 0,
  inExecution: (json['inExecution'] as num?)?.toInt() ?? 0,
  overdue: (json['overdue'] as num?)?.toInt() ?? 0,
  avgCycleMs: json['avgCycleMs'] as num?,
);

Map<String, dynamic> _$OsMetricsToJson(_OsMetrics instance) =>
    <String, dynamic>{
      'byStatus': instance.byStatus,
      'revenue': instance.revenue,
      'avgTicket': instance.avgTicket,
      'inExecution': instance.inExecution,
      'overdue': instance.overdue,
      'avgCycleMs': instance.avgCycleMs,
    };

_LowStockItem _$LowStockItemFromJson(Map<String, dynamic> json) =>
    _LowStockItem(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      currentStock: json['current_stock'] as num? ?? 0,
      minStock: json['min_stock'] as num?,
    );

Map<String, dynamic> _$LowStockItemToJson(_LowStockItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'sku': instance.sku,
      'current_stock': instance.currentStock,
      'min_stock': instance.minStock,
    };

_InventoryMetrics _$InventoryMetricsFromJson(Map<String, dynamic> json) =>
    _InventoryMetrics(
      belowMin: (json['belowMin'] as num?)?.toInt() ?? 0,
      stockValue: json['stockValue'] as num? ?? 0,
      products: (json['products'] as num?)?.toInt() ?? 0,
      services: (json['services'] as num?)?.toInt() ?? 0,
      lowStockSample:
          (json['lowStockSample'] as List<dynamic>?)
              ?.map((e) => LowStockItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LowStockItem>[],
    );

Map<String, dynamic> _$InventoryMetricsToJson(_InventoryMetrics instance) =>
    <String, dynamic>{
      'belowMin': instance.belowMin,
      'stockValue': instance.stockValue,
      'products': instance.products,
      'services': instance.services,
      'lowStockSample': instance.lowStockSample.map((e) => e.toJson()).toList(),
    };

_CustomersMetrics _$CustomersMetricsFromJson(Map<String, dynamic> json) =>
    _CustomersMetrics(
      active: (json['active'] as num?)?.toInt() ?? 0,
      newInRange: (json['newInRange'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CustomersMetricsToJson(_CustomersMetrics instance) =>
    <String, dynamic>{
      'active': instance.active,
      'newInRange': instance.newInRange,
    };
