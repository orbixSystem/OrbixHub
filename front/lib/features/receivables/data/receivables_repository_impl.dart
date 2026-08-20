import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/receivables_models.dart';
import '../domain/receivables_repository.dart';

/// [ReceivablesRepository] real, sobre dio.
class ReceivablesRepositoryImpl implements ReceivablesRepository {
  ReceivablesRepositoryImpl(this._dio);

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
  Future<DebtorsPage> listDebtors() => _guard(() async {
        final res = await _dio.get<Object?>('/receivables');
        return DebtorsPage.fromJson(_asMap(res.data));
      });

  @override
  Future<OpenTitlesPage> listOpenTitles() => _guard(() async {
        final res = await _dio.get<Object?>('/receivables/titulos');
        return OpenTitlesPage.fromJson(_asMap(res.data));
      });

  @override
  Future<OpenTitlesPage> listPendingSettlement() => _guard(() async {
        final res = await _dio.get<Object?>('/receivables/pendentes');
        return OpenTitlesPage.fromJson(_asMap(res.data));
      });

  @override
  Future<DebtorDetail> titlesOf(String? customerId) => _guard(() async {
        // Venda de balcão sem cliente tem rota literal própria (não é um uuid).
        final path = customerId == null
            ? '/receivables/sem-cliente'
            : '/receivables/$customerId';
        final res = await _dio.get<Object?>(path);
        return DebtorDetail.fromJson(_asMap(res.data));
      });
}
