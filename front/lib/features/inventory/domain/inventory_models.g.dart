// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InventoryItem _$InventoryItemFromJson(Map<String, dynamic> json) =>
    _InventoryItem(
      id: json['id'] as String,
      kind: json['kind'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      barcode: json['barcode'] as String?,
      category: json['category'] as String?,
      unit: json['unit'] as String,
      salePriceCents: (json['sale_price_cents'] as num?)?.toInt() ?? 0,
      costPriceCents: (json['cost_price_cents'] as num?)?.toInt(),
      marginPercent: json['margin_percent'] as String?,
      sellable: json['sellable'] as bool? ?? true,
      trackStock: json['track_stock'] as bool? ?? true,
      stockQty: json['stock_qty'] as String? ?? '0',
      minQty: json['min_qty'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      brand: json['brand'] as String?,
      status: json['status'] as String,
    );

Map<String, dynamic> _$InventoryItemToJson(_InventoryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'name': instance.name,
      'code': instance.code,
      'barcode': instance.barcode,
      'category': instance.category,
      'unit': instance.unit,
      'sale_price_cents': instance.salePriceCents,
      'cost_price_cents': instance.costPriceCents,
      'margin_percent': instance.marginPercent,
      'sellable': instance.sellable,
      'track_stock': instance.trackStock,
      'stock_qty': instance.stockQty,
      'min_qty': instance.minQty,
      'duration_minutes': instance.durationMinutes,
      'brand': instance.brand,
      'status': instance.status,
    };

_InventoryMovement _$InventoryMovementFromJson(Map<String, dynamic> json) =>
    _InventoryMovement(
      id: json['id'] as String,
      type: json['type'] as String,
      quantity: json['quantity'] as String,
      balanceAfter: json['balance_after'] as String,
      reason: json['reason'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$InventoryMovementToJson(_InventoryMovement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'quantity': instance.quantity,
      'balance_after': instance.balanceAfter,
      'reason': instance.reason,
      'note': instance.note,
      'created_at': instance.createdAt,
    };

_ItemPage _$ItemPageFromJson(Map<String, dynamic> json) => _ItemPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <InventoryItem>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$ItemPageToJson(_ItemPage instance) => <String, dynamic>{
  'items': instance.items,
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

_InventoryConfig _$InventoryConfigFromJson(Map<String, dynamic> json) =>
    _InventoryConfig(
      defaultUnit: json['defaultUnit'] as String? ?? 'un',
      trackStockDefault: json['trackStockDefault'] as bool? ?? true,
      defaultMarginPercent: (json['defaultMarginPercent'] as num?)?.toDouble(),
      categories:
          (json['categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$InventoryConfigToJson(_InventoryConfig instance) =>
    <String, dynamic>{
      'defaultUnit': instance.defaultUnit,
      'trackStockDefault': instance.trackStockDefault,
      'defaultMarginPercent': instance.defaultMarginPercent,
      'categories': instance.categories,
    };
