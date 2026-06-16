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
    String? category,
    String active = 'true',
    bool lowStock = false,
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/items',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            if (category != null && category.isNotEmpty) 'category': category,
            'active': active,
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
  Future<LookupResult> lookup(String code) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/lookup',
          queryParameters: {'code': code},
        );
        return LookupResult.fromJson(_asMap(res.data));
      });

  @override
  Future<String> suggestSku(String name) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/sku-suggestion',
          queryParameters: {'name': name},
        );
        return _asMap(res.data)['sku'] as String;
      });

  @override
  Future<List<InventoryItem>> lowStock() => _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/items',
          queryParameters: {'lowStock': true, 'active': 'true'},
        );
        return _asList(_asMap(res.data)['items'])
            .map(InventoryItem.fromJson)
            .toList();
      });
}
