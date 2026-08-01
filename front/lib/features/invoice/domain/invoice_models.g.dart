// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Invoice _$InvoiceFromJson(Map<String, dynamic> json) => _Invoice(
  id: json['id'] as String,
  documentType: json['document_type'] as String? ?? 'nfse',
  status: json['status'] as String? ?? 'draft',
  environment: json['environment'] as String?,
  orderId: json['order_id'] as String?,
  saleId: json['sale_id'] as String?,
  orderNumber: json['order_number'] as String?,
  customerId: json['customer_id'] as String?,
  customerName: json['customer_name'] as String?,
  customerDocument: json['customer_document'] as String?,
  series: json['series'] as String?,
  number: json['number'] as String?,
  accessKey: json['access_key'] as String?,
  serviceAmount: json['service_amount'] as String?,
  productAmount: json['product_amount'] as String?,
  totalAmount: json['total_amount'] as String?,
  pdfUrl: json['pdf_url'] as String?,
  xmlUrl: json['xml_url'] as String?,
  rejectionReason: json['rejection_reason'] as String?,
  authorizedAt: json['authorized_at'] as String?,
  canceledAt: json['canceled_at'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <InvoiceLine>[],
  events:
      (json['events'] as List<dynamic>?)
          ?.map((e) => InvoiceEvent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <InvoiceEvent>[],
);

Map<String, dynamic> _$InvoiceToJson(_Invoice instance) => <String, dynamic>{
  'id': instance.id,
  'document_type': instance.documentType,
  'status': instance.status,
  'environment': instance.environment,
  'order_id': instance.orderId,
  'sale_id': instance.saleId,
  'order_number': instance.orderNumber,
  'customer_id': instance.customerId,
  'customer_name': instance.customerName,
  'customer_document': instance.customerDocument,
  'series': instance.series,
  'number': instance.number,
  'access_key': instance.accessKey,
  'service_amount': instance.serviceAmount,
  'product_amount': instance.productAmount,
  'total_amount': instance.totalAmount,
  'pdf_url': instance.pdfUrl,
  'xml_url': instance.xmlUrl,
  'rejection_reason': instance.rejectionReason,
  'authorized_at': instance.authorizedAt,
  'canceled_at': instance.canceledAt,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'events': instance.events.map((e) => e.toJson()).toList(),
};

_InvoiceLine _$InvoiceLineFromJson(Map<String, dynamic> json) => _InvoiceLine(
  kind: json['kind'] as String? ?? 'product',
  name: json['name'] as String,
  quantity: json['quantity'] as String? ?? '0',
  unitPrice: json['unit_price'] as String? ?? '0',
  total: json['total'] as String? ?? '0',
);

Map<String, dynamic> _$InvoiceLineToJson(_InvoiceLine instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'name': instance.name,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'total': instance.total,
    };

_InvoiceEvent _$InvoiceEventFromJson(Map<String, dynamic> json) =>
    _InvoiceEvent(
      kind: json['kind'] as String,
      message: json['message'] as String?,
      statusSnapshot: json['status_snapshot'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$InvoiceEventToJson(_InvoiceEvent instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'message': instance.message,
      'status_snapshot': instance.statusSnapshot,
      'created_at': instance.createdAt,
    };

_InvoicePage _$InvoicePageFromJson(Map<String, dynamic> json) => _InvoicePage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Invoice>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$InvoicePageToJson(_InvoicePage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };
