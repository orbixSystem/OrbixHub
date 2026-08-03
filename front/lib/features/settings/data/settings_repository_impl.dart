import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<SettingsBundle> fetch() async {
    final res = await _dio.get<Object?>('/settings');
    return SettingsBundle.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch) async {
    final res = await _dio.patch<Object?>('/settings/company', data: patch);
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> updateAppearance(Map<String, dynamic> patch) async {
    final res = await _dio.patch<Object?>('/settings/appearance', data: patch);
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> updateSection(
    String key,
    Map<String, dynamic> values,
  ) async {
    // O backend devolve os valores efetivos da seção (já validados pelo módulo
    // dono), não a empresa — por isso não há `['company']` aqui.
    final res = await _dio.patch<Object?>(
      '/settings/section/$key',
      data: {'values': values},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> uploadLogo(Uint8List bytes, String filename, String contentType) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename,
          contentType: DioMediaType.parse(contentType)),
    });
    final res = await _dio.post<Object?>('/settings/company/logo', data: form);
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> removeLogo() async {
    final res = await _dio.delete<Object?>('/settings/company/logo');
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }
}
