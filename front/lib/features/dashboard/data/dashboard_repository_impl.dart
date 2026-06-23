import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';

/// [DashboardRepository] real, sobre dio. Cada chamada bate no `/metrics` do
/// módulo dono; cada endpoint é gated pelo backend (módulo + permissão de leitura).
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._dio);

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
  Future<OsMetrics> osMetrics({
    required MetricsRange range,
    String? assignedTo,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/os/metrics',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (assignedTo != null && assignedTo.isNotEmpty)
              'assignedTo': assignedTo,
          },
        );
        return OsMetrics.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryMetrics> inventoryMetrics() => _guard(() async {
        final res = await _dio.get<Object?>('/inventory/metrics');
        return InventoryMetrics.fromJson(_asMap(res.data));
      });

  @override
  Future<CustomersMetrics> customersMetrics({required MetricsRange range}) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/customers/metrics',
          queryParameters: {'from': range.fromIso, 'to': range.toIso},
        );
        return CustomersMetrics.fromJson(_asMap(res.data));
      });
}
