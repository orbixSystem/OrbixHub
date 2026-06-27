import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/notifications_models.dart';
import '../domain/notifications_repository.dart';

/// Real [NotificationsRepository] backed by dio.
class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._dio);

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
  Future<NotificationsResult> list() => _guard(() async {
        final res = await _dio.get<Object?>('/notifications');
        return NotificationsResult.fromJson(_asMap(res.data));
      });

  @override
  Future<void> markRead(String id) => _guard(() async {
        await _dio.post<Object?>('/notifications/$id/read');
      });

  @override
  Future<void> markAllRead() => _guard(() async {
        await _dio.post<Object?>('/notifications/read-all');
      });
}
