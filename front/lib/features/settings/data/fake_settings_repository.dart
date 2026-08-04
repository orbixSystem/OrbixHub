import 'dart:typed_data';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  Map<String, dynamic> _company = {'companyName': 'Oficina Demo', 'themePreset': 'tangerina'};

  @override
  Future<SettingsBundle> fetch() async => SettingsBundle(
        company: Map.of(_company),
        sections: const [
          SettingsSection(key: 'company', title: 'Empresa & Identidade visual', fields: []),
        ],
      );
  @override
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch) async {
    _company = {..._company, ...patch};
    return Map.of(_company);
  }

  @override
  Future<Map<String, dynamic>> updateAppearance(Map<String, dynamic> patch) async {
    // Apenas os 3 campos de aparência são mergeados.
    final allowed = {'themePreset', 'primaryColor', 'secondaryColor'};
    final filtered = {for (final e in patch.entries) if (allowed.contains(e.key)) e.key: e.value};
    _company = {..._company, ...filtered};
    return Map.of(_company);
  }
  /// Valores por seção de módulo (o fake guarda o que foi salvo).
  final Map<String, Map<String, dynamic>> _secoes = {};

  @override
  Future<Map<String, dynamic>> updateSection(
    String key,
    Map<String, dynamic> values,
  ) async {
    _secoes[key] = {...?_secoes[key], ...values};
    return Map.of(_secoes[key]!);
  }

  @override
  Future<Map<String, dynamic>> uploadLogo(Uint8List b, String f, String c) async {
    _company = {..._company, 'logoUrl': 'https://example/logo.png'};
    return Map.of(_company);
  }
  @override
  Future<Map<String, dynamic>> removeLogo() async {
    _company = {..._company}..remove('logoUrl');
    return Map.of(_company);
  }
}
