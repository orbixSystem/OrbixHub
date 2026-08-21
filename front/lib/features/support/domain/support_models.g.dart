// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'support_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SupportMessage _$SupportMessageFromJson(Map<String, dynamic> json) =>
    _SupportMessage(
      id: json['id'] as String,
      body: json['body'] as String,
      fromOrbix: json['fromOrbix'] as bool? ?? false,
      authorName: json['authorName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$SupportMessageToJson(_SupportMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'body': instance.body,
      'fromOrbix': instance.fromOrbix,
      'authorName': instance.authorName,
      'createdAt': instance.createdAt.toIso8601String(),
    };
