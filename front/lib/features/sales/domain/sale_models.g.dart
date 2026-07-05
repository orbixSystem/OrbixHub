// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Sale _$SaleFromJson(Map<String, dynamic> json) => _Sale(
  id: json['id'] as String,
  number: json['number'] as String?,
  customerId: json['customer_id'] as String?,
  customerName: json['customer_name'] as String?,
  status: json['status'] as String? ?? 'concluida',
  paymentMethod: json['payment_method'] as String? ?? 'dinheiro',
  discount: json['discount'] as String? ?? '0',
  subtotal: json['subtotal'] as String? ?? '0',
  total: json['total'] as String? ?? '0',
  stockApplied: json['stock_applied'] as bool? ?? false,
  createdAt: json['created_at'] as String?,
  canceledAt: json['canceled_at'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <SaleItem>[],
);

Map<String, dynamic> _$SaleToJson(_Sale instance) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'customer_id': instance.customerId,
  'customer_name': instance.customerName,
  'status': instance.status,
  'payment_method': instance.paymentMethod,
  'discount': instance.discount,
  'subtotal': instance.subtotal,
  'total': instance.total,
  'stock_applied': instance.stockApplied,
  'created_at': instance.createdAt,
  'canceled_at': instance.canceledAt,
  'items': instance.items,
};

_SaleItem _$SaleItemFromJson(Map<String, dynamic> json) => _SaleItem(
  id: json['id'] as String,
  inventoryItemId: json['inventory_item_id'] as String?,
  kind: json['kind'] as String? ?? 'product',
  name: json['name'] as String,
  quantity: json['quantity'] as String? ?? '1',
  unitPrice: json['unit_price'] as String? ?? '0',
  discount: json['discount'] as String? ?? '0',
  total: json['total'] as String? ?? '0',
);

Map<String, dynamic> _$SaleItemToJson(_SaleItem instance) => <String, dynamic>{
  'id': instance.id,
  'inventory_item_id': instance.inventoryItemId,
  'kind': instance.kind,
  'name': instance.name,
  'quantity': instance.quantity,
  'unit_price': instance.unitPrice,
  'discount': instance.discount,
  'total': instance.total,
};

_SalePage _$SalePageFromJson(Map<String, dynamic> json) => _SalePage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => Sale.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Sale>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$SalePageToJson(_SalePage instance) => <String, dynamic>{
  'items': instance.items,
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
};
