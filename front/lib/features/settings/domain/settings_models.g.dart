// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SettingsFieldOption _$SettingsFieldOptionFromJson(Map<String, dynamic> json) =>
    _SettingsFieldOption(
      value: json['value'] as String,
      label: json['label'] as String,
    );

Map<String, dynamic> _$SettingsFieldOptionToJson(
  _SettingsFieldOption instance,
) => <String, dynamic>{'value': instance.value, 'label': instance.label};

_SettingsField _$SettingsFieldFromJson(Map<String, dynamic> json) =>
    _SettingsField(
      key: json['key'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (e) => SettingsFieldOption.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <SettingsFieldOption>[],
      group: json['group'] as String?,
    );

Map<String, dynamic> _$SettingsFieldToJson(_SettingsField instance) =>
    <String, dynamic>{
      'key': instance.key,
      'label': instance.label,
      'type': instance.type,
      'options': instance.options.map((e) => e.toJson()).toList(),
      'group': instance.group,
    };

_SettingsSection _$SettingsSectionFromJson(Map<String, dynamic> json) =>
    _SettingsSection(
      key: json['key'] as String,
      title: json['title'] as String,
      moduleKey: json['moduleKey'] as String?,
      fields:
          (json['fields'] as List<dynamic>?)
              ?.map((e) => SettingsField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SettingsField>[],
      values:
          json['values'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$SettingsSectionToJson(_SettingsSection instance) =>
    <String, dynamic>{
      'key': instance.key,
      'title': instance.title,
      'moduleKey': instance.moduleKey,
      'fields': instance.fields.map((e) => e.toJson()).toList(),
      'values': instance.values,
    };

_SettingsBundle _$SettingsBundleFromJson(Map<String, dynamic> json) =>
    _SettingsBundle(
      company:
          json['company'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      sections:
          (json['sections'] as List<dynamic>?)
              ?.map((e) => SettingsSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SettingsSection>[],
    );

Map<String, dynamic> _$SettingsBundleToJson(_SettingsBundle instance) =>
    <String, dynamic>{
      'company': instance.company,
      'sections': instance.sections.map((e) => e.toJson()).toList(),
    };
