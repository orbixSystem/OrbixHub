import 'dart:typed_data';
import 'settings_models.dart';

abstract class SettingsRepository {
  Future<SettingsBundle> fetch();
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch);
  /// Atualiza apenas campos de aparência (themePreset, primaryColor, secondaryColor).
  /// Usa o endpoint PATCH /settings/appearance — acessível por qualquer membro.
  Future<Map<String, dynamic>> updateAppearance(Map<String, dynamic> patch);

  /// Aplica um patch nos valores de uma seção de config de MÓDULO (ex.: `cashier`).
  /// Devolve os valores efetivos depois de salvar.
  Future<Map<String, dynamic>> updateSection(
    String key,
    Map<String, dynamic> values,
  );
  Future<Map<String, dynamic>> uploadLogo(Uint8List bytes, String filename, String contentType);
  Future<Map<String, dynamic>> removeLogo();
}
