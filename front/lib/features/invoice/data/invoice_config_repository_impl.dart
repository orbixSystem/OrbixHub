import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/invoice_config_models.dart';
import '../domain/invoice_config_repository.dart';

/// Real [InvoiceConfigRepository] backed by dio.
class InvoiceConfigRepositoryImpl implements InvoiceConfigRepository {
  InvoiceConfigRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  InvoiceFiscalConfig _parse(Object? data) =>
      InvoiceFiscalConfig.fromJson((data as Map).cast<String, dynamic>());

  @override
  Future<InvoiceFiscalConfig> fetch() => _guard(() async =>
      _parse((await _dio.get<Object?>('/invoices/config')).data));

  @override
  Future<InvoiceFiscalConfig> update(Map<String, dynamic> patch) =>
      _guard(() async => _parse(
          (await _dio.patch<Object?>('/invoices/config', data: patch)).data));

  @override
  Future<InvoiceFiscalConfig> registerEmpresa() => _guard(() async => _parse(
      (await _dio.post<Object?>('/invoices/config/register-empresa')).data));

  @override
  Future<InvoiceFiscalConfig> uploadCertificate(
    Uint8List bytes,
    String filename,
    String password,
  ) =>
      _guard(() async {
        final form = FormData.fromMap({
          'password': password,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType('application', 'x-pkcs12'),
          ),
        });
        final res =
            await _dio.post<Object?>('/invoices/config/certificate', data: form);
        return _parse(res.data);
      });
}
