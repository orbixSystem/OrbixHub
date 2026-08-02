// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUpdate _$AppUpdateFromJson(Map<String, dynamic> json) => _AppUpdate(
  enabled: json['enabled'] as bool? ?? false,
  platform: json['platform'] as String?,
  version: json['version'] as String?,
  buildNumber: (json['buildNumber'] as num?)?.toInt(),
  minSupported: json['minSupported'] as String?,
  minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt(),
  notes: json['notes'] as String?,
  url: json['url'] as String?,
  sha256: json['sha256'] as String?,
  sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  publishedAt: json['publishedAt'] as String?,
);

Map<String, dynamic> _$AppUpdateToJson(_AppUpdate instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'platform': instance.platform,
      'version': instance.version,
      'buildNumber': instance.buildNumber,
      'minSupported': instance.minSupported,
      'minSupportedBuild': instance.minSupportedBuild,
      'notes': instance.notes,
      'url': instance.url,
      'sha256': instance.sha256,
      'sizeBytes': instance.sizeBytes,
      'publishedAt': instance.publishedAt,
    };
