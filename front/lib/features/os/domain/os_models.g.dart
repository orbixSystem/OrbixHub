// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'os_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => _OrderItem(
  id: json['id'] as String,
  kind: json['kind'] as String? ?? 'product',
  inventoryItemId: json['inventory_item_id'] as String?,
  name: json['name'] as String,
  quantity: json['quantity'] as String? ?? '1',
  unitPrice: json['unit_price'] as String? ?? '0',
  discount: json['discount'] as String? ?? '0',
  total: json['total'] as String? ?? '0',
  assignedTo: json['assigned_to'] as String?,
  scheduledStart: json['scheduled_start'] as String?,
  estimatedDuration: (json['estimated_duration'] as num?)?.toInt(),
  scheduledEnd: json['scheduled_end'] as String?,
);

Map<String, dynamic> _$OrderItemToJson(_OrderItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'inventory_item_id': instance.inventoryItemId,
      'name': instance.name,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'discount': instance.discount,
      'total': instance.total,
      'assigned_to': instance.assignedTo,
      'scheduled_start': instance.scheduledStart,
      'estimated_duration': instance.estimatedDuration,
      'scheduled_end': instance.scheduledEnd,
    };

_OrderEvent _$OrderEventFromJson(Map<String, dynamic> json) => _OrderEvent(
  id: json['id'] as String,
  kind: json['kind'] as String? ?? 'note',
  message: json['message'] as String?,
  statusSnapshot: json['status_snapshot'] as String?,
  visiblePublic: json['visible_public'] as bool? ?? false,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$OrderEventToJson(_OrderEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'message': instance.message,
      'status_snapshot': instance.statusSnapshot,
      'visible_public': instance.visiblePublic,
      'created_at': instance.createdAt,
    };

_OrderPhoto _$OrderPhotoFromJson(Map<String, dynamic> json) => _OrderPhoto(
  id: json['id'] as String,
  url: json['url'] as String,
  caption: json['caption'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$OrderPhotoToJson(_OrderPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'caption': instance.caption,
      'created_at': instance.createdAt,
    };

_OsTemplateItem _$OsTemplateItemFromJson(Map<String, dynamic> json) =>
    _OsTemplateItem(
      id: json['id'] as String?,
      kind: json['kind'] as String? ?? 'product',
      inventoryItemId: json['inventory_item_id'] as String?,
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '1',
      unitPrice: json['unit_price'] as String?,
    );

Map<String, dynamic> _$OsTemplateItemToJson(_OsTemplateItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': instance.kind,
      'inventory_item_id': instance.inventoryItemId,
      'name': instance.name,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
    };

_OsTemplate _$OsTemplateFromJson(Map<String, dynamic> json) => _OsTemplate(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => OsTemplateItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <OsTemplateItem>[],
  total: json['total'] as String?,
);

Map<String, dynamic> _$OsTemplateToJson(_OsTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'items': instance.items,
      'total': instance.total,
    };

_ServiceOrder _$ServiceOrderFromJson(Map<String, dynamic> json) =>
    _ServiceOrder(
      id: json['id'] as String,
      number: json['number'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String?,
      subjectId: json['subject_id'] as String?,
      subjectLabel: json['subject_label'] as String?,
      status: json['status'] as String? ?? 'aberta',
      assignedTo: json['assigned_to'] as String?,
      complaint: json['complaint'] as String?,
      diagnosis: json['diagnosis'] as String?,
      scheduledStart: json['scheduled_start'] as String?,
      scheduledEnd: json['scheduled_end'] as String?,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      publicToken: json['public_token'] as String?,
      discount: json['discount'] as String?,
      total: json['total'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <OrderItem>[],
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => OrderEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <OrderEvent>[],
      photos:
          (json['photos'] as List<dynamic>?)
              ?.map((e) => OrderPhoto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <OrderPhoto>[],
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$ServiceOrderToJson(_ServiceOrder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'customer_id': instance.customerId,
      'customer_name': instance.customerName,
      'subject_id': instance.subjectId,
      'subject_label': instance.subjectLabel,
      'status': instance.status,
      'assigned_to': instance.assignedTo,
      'complaint': instance.complaint,
      'diagnosis': instance.diagnosis,
      'scheduled_start': instance.scheduledStart,
      'scheduled_end': instance.scheduledEnd,
      'started_at': instance.startedAt,
      'finished_at': instance.finishedAt,
      'public_token': instance.publicToken,
      'discount': instance.discount,
      'total': instance.total,
      'items': instance.items,
      'events': instance.events,
      'photos': instance.photos,
      'created_at': instance.createdAt,
    };

_OrderPage _$OrderPageFromJson(Map<String, dynamic> json) => _OrderPage(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => ServiceOrder.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ServiceOrder>[],
  total: (json['total'] as num?)?.toInt() ?? 0,
  page: (json['page'] as num?)?.toInt() ?? 1,
  pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
);

Map<String, dynamic> _$OrderPageToJson(_OrderPage instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'page': instance.page,
      'pageSize': instance.pageSize,
    };

_CustomerOption _$CustomerOptionFromJson(Map<String, dynamic> json) =>
    _CustomerOption(
      id: json['id'] as String,
      name: json['name'] as String,
      document: json['document'] as String?,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$CustomerOptionToJson(_CustomerOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'document': instance.document,
      'phone': instance.phone,
    };

_SubjectOption _$SubjectOptionFromJson(Map<String, dynamic> json) =>
    _SubjectOption(
      id: json['id'] as String,
      label: json['label'] as String?,
      identifier: json['identifier'] as String?,
    );

Map<String, dynamic> _$SubjectOptionToJson(_SubjectOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'identifier': instance.identifier,
    };

_InventoryOption _$InventoryOptionFromJson(Map<String, dynamic> json) =>
    _InventoryOption(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String? ?? 'product',
      salePrice: json['sale_price'] as String?,
      currentStock: json['current_stock'] as String?,
    );

Map<String, dynamic> _$InventoryOptionToJson(_InventoryOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'kind': instance.kind,
      'sale_price': instance.salePrice,
      'current_stock': instance.currentStock,
    };
