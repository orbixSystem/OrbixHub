import 'package:freezed_annotation/freezed_annotation.dart';
part 'settings_models.freezed.dart';
part 'settings_models.g.dart';

@freezed
abstract class SettingsFieldOption with _$SettingsFieldOption {
  const factory SettingsFieldOption({required String value, required String label}) = _SettingsFieldOption;
  factory SettingsFieldOption.fromJson(Map<String, dynamic> j) => _$SettingsFieldOptionFromJson(j);
}

@freezed
abstract class SettingsField with _$SettingsField {
  const factory SettingsField({
    required String key,
    required String label,
    required String type,
    @Default(<SettingsFieldOption>[]) List<SettingsFieldOption> options,
    String? group,
  }) = _SettingsField;
  factory SettingsField.fromJson(Map<String, dynamic> j) => _$SettingsFieldFromJson(j);
}

@freezed
abstract class SettingsSection with _$SettingsSection {
  const factory SettingsSection({
    required String key,
    required String title,
    String? moduleKey,
    @Default(<SettingsField>[]) List<SettingsField> fields,
  }) = _SettingsSection;
  factory SettingsSection.fromJson(Map<String, dynamic> j) => _$SettingsSectionFromJson(j);
}

@freezed
abstract class SettingsBundle with _$SettingsBundle {
  const factory SettingsBundle({
    @Default(<String, dynamic>{}) Map<String, dynamic> company,
    @Default(<SettingsSection>[]) List<SettingsSection> sections,
  }) = _SettingsBundle;
  factory SettingsBundle.fromJson(Map<String, dynamic> j) => _$SettingsBundleFromJson(j);
}
