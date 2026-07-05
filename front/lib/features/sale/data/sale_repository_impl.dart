import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/sale_models.dart';
import '../domain/sale_repository.dart';

/// [SaleRepository] real, sobre dio.
class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._dio);

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
  Future<SalePage> listSales({String? status, String? customerId, int page = 1}) =>
      _guard(() async {
        final res = await _dio.get<Object?>('/sales', queryParameters: {
          'status': ?status,
          'customerId': ?customerId,
          'page': page,
        });
        return SalePage.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> getSale(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/sales/$id');
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> createSale(SaleDraft draft) => _guard(() async {
        final res = await _dio.post<Object?>('/sales', data: draft.toJson());
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> cancelSale(String id, {String? reason}) => _guard(() async {
        final res = await _dio.post<Object?>('/sales/$id/cancel', data: {
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        });
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<SaleFiscalResult> emitInvoice(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/sales/$id/invoice', data: {});
        return SaleFiscalResult.fromJson(_asMap(res.data));
      });
}
