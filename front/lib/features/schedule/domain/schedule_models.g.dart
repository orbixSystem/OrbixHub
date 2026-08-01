// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BusinessHours _$BusinessHoursFromJson(Map<String, dynamic> json) =>
    _BusinessHours(
      id: json['id'] as String,
      dayOfWeek: (json['dayOfWeek'] as num).toInt(),
      dayLabel: json['dayLabel'] as String,
      isOpen: json['isOpen'] as bool? ?? true,
      openTime: json['openTime'] as String? ?? '08:00',
      closeTime: json['closeTime'] as String? ?? '18:00',
    );

Map<String, dynamic> _$BusinessHoursToJson(_BusinessHours instance) =>
    <String, dynamic>{
      'id': instance.id,
      'dayOfWeek': instance.dayOfWeek,
      'dayLabel': instance.dayLabel,
      'isOpen': instance.isOpen,
      'openTime': instance.openTime,
      'closeTime': instance.closeTime,
    };

_AgendaOrderRef _$AgendaOrderRefFromJson(Map<String, dynamic> json) =>
    _AgendaOrderRef(
      id: json['id'] as String,
      number: json['number'] as String,
      status: json['status'] as String? ?? 'aberta',
      customerName: json['customer_name'] as String?,
      subjectLabel: json['subject_label'] as String?,
    );

Map<String, dynamic> _$AgendaOrderRefToJson(_AgendaOrderRef instance) =>
    <String, dynamic>{
      'id': instance.id,
      'number': instance.number,
      'status': instance.status,
      'customer_name': instance.customerName,
      'subject_label': instance.subjectLabel,
    };

_AgendaItem _$AgendaItemFromJson(Map<String, dynamic> json) => _AgendaItem(
  id: json['id'] as String,
  name: json['name'] as String,
  kind: json['kind'] as String? ?? 'service',
  assignedTo: json['assigned_to'] as String?,
  assignedToName: json['assigned_to_name'] as String?,
  scheduledStart: json['scheduled_start'] as String?,
  scheduledEnd: json['scheduled_end'] as String?,
  estimatedDuration: (json['estimated_duration'] as num?)?.toInt(),
  orderId: json['order_id'] as String,
  order: AgendaOrderRef.fromJson(json['order'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AgendaItemToJson(_AgendaItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'kind': instance.kind,
      'assigned_to': instance.assignedTo,
      'assigned_to_name': instance.assignedToName,
      'scheduled_start': instance.scheduledStart,
      'scheduled_end': instance.scheduledEnd,
      'estimated_duration': instance.estimatedDuration,
      'order_id': instance.orderId,
      'order': instance.order.toJson(),
    };

_AgendaResult _$AgendaResultFromJson(Map<String, dynamic> json) =>
    _AgendaResult(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => AgendaItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AgendaItem>[],
    );

Map<String, dynamic> _$AgendaResultToJson(_AgendaResult instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
