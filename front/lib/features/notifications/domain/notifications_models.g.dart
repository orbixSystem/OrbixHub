// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      refType: json['ref_type'] as String?,
      refId: json['ref_id'] as String?,
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'body': instance.body,
      'ref_type': instance.refType,
      'ref_id': instance.refId,
      'read_at': instance.readAt,
      'created_at': instance.createdAt,
    };

_NotificationsResult _$NotificationsResultFromJson(Map<String, dynamic> json) =>
    _NotificationsResult(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AppNotification>[],
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$NotificationsResultToJson(
  _NotificationsResult instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'unread': instance.unread,
};
