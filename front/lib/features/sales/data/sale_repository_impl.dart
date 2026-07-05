import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/sale_models.dart';
import '../domain/sale_repository.dart';

/// Real [SaleRepository] backed by dio.
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
  Future<SalePage> list({
    int page = 1,
    String? status,
    String? customerId,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/sales',
          queryParameters: {
            'page': page,
            if (status != null && status.isNotEmpty) 'status': status,
            if (customerId != null && customerId.isNotEmpty)
              'customerId': customerId,
          },
        );
        return SalePage.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> getOne(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/sales/$id');
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> checkout(SaleDraft draft) => _guard(() async {
        final res = await _dio.post<Object?>('/sales', data: draft.toJson());
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> cancel(String id, String reason) => _guard(() async {
        final res = await _dio.post<Object?>(
          '/sales/$id/cancel',
          data: {'reason': reason},
        );
        return Sale.fromJson(_asMap(res.data));
      });
}
