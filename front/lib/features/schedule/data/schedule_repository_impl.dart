import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/schedule_models.dart';
import '../domain/schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl(this._dio);

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
  Future<List<BusinessHours>> getBusinessHours() => _guard(() async {
        final res = await _dio.get<Object?>('/schedule/business-hours');
        final list = (res.data as List).cast<Map<String, dynamic>>();
        return list.map(BusinessHours.fromJson).toList();
      });

  @override
  Future<BusinessHours> updateBusinessHours(
      int day, BusinessHoursPatch patch) =>
      _guard(() async {
        final res = await _dio.patch<Object?>(
          '/schedule/business-hours/$day',
          data: patch.toJson(),
        );
        return BusinessHours.fromJson(_asMap(res.data));
      });

  @override
  Future<AgendaResult> getAgenda({
    required DateTime from,
    required DateTime to,
    String? assignedTo,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/schedule/agenda',
          queryParameters: {
            'from': from.toUtc().toIso8601String(),
            'to': to.toUtc().toIso8601String(),
            'assignedTo': ?assignedTo,
          },
        );
        return AgendaResult.fromJson(_asMap(res.data));
      });

  @override
  Future<Map<String, dynamic>> scheduleItem(
    String orderId,
    String itemId,
    ScheduleItemDraft draft,
  ) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/schedule/orders/$orderId/items/$itemId',
          data: draft.toJson(),
        );
        return _asMap(res.data);
      });

  @override
  Future<Map<String, dynamic>> unscheduleItem(
      String orderId, String itemId) =>
      _guard(() async {
        final res = await _dio.delete<Object?>(
          '/schedule/orders/$orderId/items/$itemId',
        );
        return _asMap(res.data);
      });
}
