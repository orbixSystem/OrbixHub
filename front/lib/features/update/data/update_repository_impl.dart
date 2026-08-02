import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/update_models.dart';
import '../domain/update_repository.dart';

class UpdateRepositoryImpl implements UpdateRepository {
  UpdateRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<AppUpdate> latest(String platform) async {
    try {
      final res = await _dio.get<Object?>(
        '/app/update',
        queryParameters: {'platform': platform},
      );
      final data = res.data;
      if (data is! Map) return const AppUpdate();
      return AppUpdate.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}

/// Fake para dev/teste: por padrão diz que está tudo em dia.
class FakeUpdateRepository implements UpdateRepository {
  FakeUpdateRepository([this.response = const AppUpdate()]);

  final AppUpdate response;

  @override
  Future<AppUpdate> latest(String platform) async => response;
}
