import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/os_models.dart';
import '../domain/os_repository.dart';

/// Real [OsRepository] backed by dio.
class OsRepositoryImpl implements OsRepository {
  OsRepositoryImpl(this._dio);

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

  List<Map<String, dynamic>> _asList(Object? data) =>
      (data as List).cast<Map<String, dynamic>>();

  @override
  Future<OrderPage> listOrders({
    String? q,
    String? status,
    String? customerId,
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/os/orders',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            if (status != null && status.isNotEmpty) 'status': status,
            if (customerId != null && customerId.isNotEmpty)
              'customerId': customerId,
            'page': page,
          },
        );
        return OrderPage.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> getOrder(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/os/orders/$id');
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> createOrder(OrderDraft draft) => _guard(() async {
        final res =
            await _dio.post<Object?>('/os/orders', data: draft.toJson());
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> updateOrder(String id, OrderPatch patch) =>
      _guard(() async {
        final res =
            await _dio.patch<Object?>('/os/orders/$id', data: patch.toJson());
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<void> deleteOrder(String id) => _guard(() async {
        await _dio.delete<Object?>('/os/orders/$id');
      });

  @override
  Future<ServiceOrder> changeStatus(String id, String status) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/os/orders/$id/status',
          data: {'status': status},
        );
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> addItem(String id, OrderItemDraft draft) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/os/orders/$id/items',
          data: draft.toJson(),
        );
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> updateItem(
    String id,
    String itemId,
    OrderItemPatch patch,
  ) =>
      _guard(() async {
        final res = await _dio.patch<Object?>(
          '/os/orders/$id/items/$itemId',
          data: patch.toJson(),
        );
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> deleteItem(String id, String itemId) =>
      _guard(() async {
        final res =
            await _dio.delete<Object?>('/os/orders/$id/items/$itemId');
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<List<InventoryOption>> searchInventory(String q) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/items',
          queryParameters: {
            if (q.isNotEmpty) 'q': q,
            'status': 'active',
          },
        );
        return _asList(_asMap(res.data)['items'])
            .map(InventoryOption.fromJson)
            .toList();
      });

  @override
  Future<List<CustomerOption>> searchCustomers(String q) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/customers',
          queryParameters: {
            if (q.isNotEmpty) 'q': q,
            'status': 'active',
          },
        );
        return _asList(_asMap(res.data)['items'])
            .map(CustomerOption.fromJson)
            .toList();
      });

  @override
  Future<List<SubjectOption>> subjectsOf(String customerId) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/subjects',
          queryParameters: {'customerId': customerId, 'status': 'active'},
        );
        return _asList(_asMap(res.data)['items'])
            .map(SubjectOption.fromJson)
            .toList();
      });
}
