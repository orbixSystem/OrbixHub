import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/invoice_models.dart';
import '../domain/invoice_repository.dart';

/// Real [InvoiceRepository] backed by dio.
class InvoiceRepositoryImpl implements InvoiceRepository {
  InvoiceRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Map<String, dynamic> _asMap(Object? data) =>
      (data as Map).cast<String, dynamic>();

  @override
  Future<InvoicePage> list({
    int page = 1,
    String? status,
    String? orderId,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/invoices',
          queryParameters: {
            'page': page,
            if (status != null && status.isNotEmpty) 'status': status,
            if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
          },
        );
        return InvoicePage.fromJson(_asMap(res.data));
      });

  @override
  Future<Invoice> getOne(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/invoices/$id');
        return Invoice.fromJson(_asMap(res.data));
      });

  @override
  Future<Invoice> issue({String? orderId, String? saleId, String? documentType}) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/invoices',
          data: {
            'orderId': ?orderId,
            'saleId': ?saleId,
            'documentType': ?documentType,
          },
        );
        return Invoice.fromJson(_asMap(res.data));
      });

  @override
  Future<Invoice> cancel(String id, String reason) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/invoices/$id/cancel',
          data: {'reason': reason},
        );
        return Invoice.fromJson(_asMap(res.data));
      });
}
