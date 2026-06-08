import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/billing_models.dart';
import '../domain/billing_repository.dart';

/// Real [BillingRepository] backed by dio.
class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<List<Plan>> fetchPlans() => _guard(() async {
        final res = await _dio.get<Object?>('/billing/plans');
        final list = (res.data as List).cast<Map<String, dynamic>>();
        return list.map(Plan.fromJson).toList();
      });

  @override
  Future<Subscription?> fetchSubscription() => _guard(() async {
        final res = await _dio.get<Object?>('/billing/subscription');
        final data = res.data;
        if (data == null) return null;
        return Subscription.fromJson((data as Map).cast<String, dynamic>());
      });

  @override
  Future<Subscription> subscribe(String planKey) => _guard(() async {
        final res = await _dio
            .post<Object?>('/billing/subscribe', data: {'planKey': planKey});
        return Subscription.fromJson((res.data as Map).cast<String, dynamic>());
      });

  @override
  Future<Subscription> changePlan(String planKey) => _guard(() async {
        final res = await _dio
            .post<Object?>('/billing/change-plan', data: {'planKey': planKey});
        return Subscription.fromJson((res.data as Map).cast<String, dynamic>());
      });
}
