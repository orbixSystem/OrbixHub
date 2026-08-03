// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Sale _$SaleFromJson(Map<String, dynamic> json) => _Sale(
  id: json['id'] as String,
  number: json['number'] as String? ?? '',
  customerId: json['customer_id'] as String?,
  customerName: json['customer_name'] as String?,
  status: json['status'] as String? ?? 'active',
  total: json['total'] as String? ?? '0',
  discount: json['discount'] as String? ?? '0',
  fiscalStatus: json['fiscal_status'] as String?,
  paymentStatus: json['payment_status'] as String? ?? 'a_receber',
  createdAt: json['created_at'] as String?,
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
  'total': instance.total,
  'discount': instance.discount,
  'fiscal_status': instance.fiscalStatus,
  'payment_status': instance.paymentStatus,
  'created_at': instance.createdAt,
  'items': instance.items.map((e) => e.toJson()).toList(),
};

_SaleItem _$SaleItemFromJson(Map<String, dynamic> json) => _SaleItem(
  id: json['id'] as String,
  kind: json['kind'] as String? ?? 'product',
  inventoryItemId: json['inventory_item_id'] as String?,
  name: json['name'] as String? ?? '',
  quantity: json['quantity'] as String? ?? '1',
  unitPrice: json['unit_price'] as String? ?? '0',
  subtotal: json['subtotal'] as String? ?? '0',
);

Map<String, dynamic> _$SaleItemToJson(_SaleItem instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'inventory_item_id': instance.inventoryItemId,
  'name': instance.name,
  'quantity': instance.quantity,
  'unit_price': instance.unitPrice,
  'subtotal': instance.subtotal,
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
  'items': instance.items.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

_SaleFiscalResult _$SaleFiscalResultFromJson(Map<String, dynamic> json) =>
    _SaleFiscalResult(
      status: json['status'] as String? ?? 'nao_emitida',
      externalId: json['externalId'] as String?,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$SaleFiscalResultToJson(_SaleFiscalResult instance) =>
    <String, dynamic>{
      'status': instance.status,
      'externalId': instance.externalId,
      'message': instance.message,
    };
