import 'dart:typed_data';
import 'settings_models.dart';

abstract class SettingsRepository {
  Future<SettingsBundle> fetch();
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch);
  /// Atualiza apenas campos de aparência (themePreset, primaryColor, secondaryColor).
  /// Usa o endpoint PATCH /settings/appearance — acessível por qualquer membro.
  Future<Map<String, dynamic>> updateAppearance(Map<String, dynamic> patch);
  Future<Map<String, dynamic>> uploadLogo(Uint8List bytes, String filename, String contentType);
  Future<Map<String, dynamic>> removeLogo();
}
