import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// Real [InventoryRepository] backed by dio.
class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._dio);

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
  Future<InventoryConfig> fetchConfig() => _guard(() async {
        final res = await _dio.get<Object?>('/inventory/config');
        return InventoryConfig.fromJson(_asMap(res.data));
      });

  @override
  Future<ItemPage> listItems({
    String? q,
    String? kind,
    String? category,
    String status = 'active',
    bool lowStock = false,
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/items',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            if (kind != null && kind.isNotEmpty) 'kind': kind,
            if (category != null && category.isNotEmpty) 'category': category,
            'status': status,
            if (lowStock) 'lowStock': true,
            'page': page,
          },
        );
        return ItemPage.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryItem> getItem(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/inventory/items/$id');
        return InventoryItem.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryItem> createItem(ItemDraft draft) => _guard(() async {
        final res =
            await _dio.post<Object?>('/inventory/items', data: draft.toJson());
        return InventoryItem.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft draft) =>
      _guard(() async {
        final res = await _dio.patch<Object?>(
          '/inventory/items/$id',
          data: draft.toJson(),
        );
        return InventoryItem.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryItem> archiveItem(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/inventory/items/$id/archive');
        return InventoryItem.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryItem> unarchiveItem(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/inventory/items/$id/unarchive');
        return InventoryItem.fromJson(_asMap(res.data));
      });

  @override
  Future<List<InventoryMovement>> listMovements(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/inventory/items/$id/movements');
        return _asList(res.data).map(InventoryMovement.fromJson).toList();
      });

  @override
  Future<InventoryMovement> registerMovement(String id, MovementDraft draft) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/inventory/items/$id/movements',
          data: draft.toJson(),
        );
        return InventoryMovement.fromJson(_asMap(res.data));
      });

  @override
  Future<List<InventoryItem>> lowStock() => _guard(() async {
        final res = await _dio.get<Object?>('/inventory/low-stock');
        return _asList(res.data).map(InventoryItem.fromJson).toList();
      });
}
