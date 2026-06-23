import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../customers/domain/customers_models.dart';
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
    String sort = 'recent',
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
            if (sort.isNotEmpty) 'sort': sort,
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
  Future<ServiceOrder> createNote(
    String id, {
    required String message,
    required bool visiblePublic,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/os/orders/$id/notes',
          data: {'message': message, 'visiblePublic': visiblePublic},
        );
        final body = _asMap(res.data);
        // O backend pode devolver a OS (com `items`) ou só o evento. Se vier a
        // OS, usamos direto; senão, re-buscamos a OS atualizada.
        if (body.containsKey('items') || body.containsKey('number')) {
          return ServiceOrder.fromJson(body);
        }
        final refreshed = await _dio.get<Object?>('/os/orders/$id');
        return ServiceOrder.fromJson(_asMap(refreshed.data));
      });

  @override
  Future<ServiceOrder> addPhoto(
    String orderId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? caption,
  }) =>
      _guard(() async {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(contentType),
          ),
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        });
        await _dio.post<Object?>('/os/orders/$orderId/photos', data: form);
        // O endpoint devolve só a foto; re-buscamos a OS para ter `photos`.
        final refreshed = await _dio.get<Object?>('/os/orders/$orderId');
        return ServiceOrder.fromJson(_asMap(refreshed.data));
      });

  @override
  Future<ServiceOrder> deletePhoto(String orderId, String photoId) =>
      _guard(() async {
        await _dio.delete<Object?>('/os/orders/$orderId/photos/$photoId');
        final refreshed = await _dio.get<Object?>('/os/orders/$orderId');
        return ServiceOrder.fromJson(_asMap(refreshed.data));
      });

  @override
  Future<List<OsTemplate>> listTemplates() => _guard(() async {
        final res = await _dio.get<Object?>('/os/templates');
        final data = res.data;
        // Aceita `{ items: [...] }` ou uma lista direta.
        final raw = data is Map
            ? (data.cast<String, dynamic>()['items'] as List? ?? const [])
            : (data as List? ?? const []);
        return raw
            .cast<Map<String, dynamic>>()
            .map(OsTemplate.fromJson)
            .toList();
      });

  @override
  Future<List<OsTemplate>> listTemplatesFull() => listTemplates();

  @override
  Future<OsTemplate> getTemplate(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/os/templates/$id');
        return OsTemplate.fromJson(_asMap(res.data));
      });

  @override
  Future<OsTemplate> createTemplate(OsTemplateDraft draft) =>
      _guard(() async {
        final res =
            await _dio.post<Object?>('/os/templates', data: draft.toJson());
        return OsTemplate.fromJson(_asMap(res.data));
      });

  @override
  Future<OsTemplate> updateTemplate(String id, OsTemplateDraft draft) =>
      _guard(() async {
        final res = await _dio.patch<Object?>(
          '/os/templates/$id',
          data: draft.toJson(),
        );
        return OsTemplate.fromJson(_asMap(res.data));
      });

  @override
  Future<void> deleteTemplate(String id) => _guard(() async {
        await _dio.delete<Object?>('/os/templates/$id');
      });

  @override
  Future<ServiceOrder> applyTemplate(String orderId, String templateId) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/os/orders/$orderId/apply-template/$templateId',
        );
        return ServiceOrder.fromJson(_asMap(res.data));
      });

  @override
  Future<ServiceOrder> addItem(String id, OrderItemDraft draft) =>
      _guard(() async {
        // O endpoint devolve só o item criado (sem number/customer_id), então
        // re-buscamos a OS para ter a lista atualizada e completa.
        await _dio.post<Object?>('/os/orders/$id/items', data: draft.toJson());
        final refreshed = await _dio.get<Object?>('/os/orders/$id');
        return ServiceOrder.fromJson(_asMap(refreshed.data));
      });

  @override
  Future<ServiceOrder> updateItem(
    String id,
    String itemId,
    OrderItemPatch patch,
  ) =>
      _guard(() async {
        // Devolve só o item — re-buscamos a OS para refletir totais/lista.
        await _dio.patch<Object?>(
          '/os/orders/$id/items/$itemId',
          data: patch.toJson(),
        );
        final refreshed = await _dio.get<Object?>('/os/orders/$id');
        return ServiceOrder.fromJson(_asMap(refreshed.data));
      });

  @override
  Future<ServiceOrder> deleteItem(String id, String itemId) =>
      _guard(() async {
        // Devolve `{ id, deleted: true }` — re-buscamos a OS para a lista nova.
        await _dio.delete<Object?>('/os/orders/$id/items/$itemId');
        final refreshed = await _dio.get<Object?>('/os/orders/$id');
        return ServiceOrder.fromJson(_asMap(refreshed.data));
      });

  @override
  Future<List<InventoryOption>> searchInventory(String q) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/inventory/items',
          queryParameters: {
            if (q.isNotEmpty) 'q': q,
            'active': 'true', // ItemQueryDto usa `active`, não `status`
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

  @override
  Future<List<MemberOption>> listMembers() => _guard(() async {
        // Rota leve liberada p/ qualquer membro ativo (não exige users.manage),
        // ao contrário de `/employees` (Equipe/owner-gerente).
        final res = await _dio.get<Object?>('/employees/assignable');
        return _asList(res.data).map((m) {
          // id do membro: preferimos `userId` (uuid); fallback `membershipId`.
          final id = (m['userId'] ?? m['membershipId'] ?? m['id'])?.toString();
          final name = (m['fullName'] ?? m['name'] ?? m['email'] ?? id)
              ?.toString();
          return MemberOption(id: id ?? '', name: name ?? '');
        }).where((m) => m.id.isNotEmpty).toList();
      });

  @override
  Future<CustomersConfig> customersConfig() => _guard(() async {
        final res = await _dio.get<Object?>('/customers/config');
        return CustomersConfig.fromJson(_asMap(res.data));
      });

  @override
  Future<List<LookupOption>> lookup(
    String fonte, {
    String? marca,
    String? modelo,
    String? q,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/customers/lookups/$fonte',
          queryParameters: {
            if (marca != null && marca.isNotEmpty) 'marca': marca,
            if (modelo != null && modelo.isNotEmpty) 'modelo': modelo,
            if (q != null && q.isNotEmpty) 'q': q,
          },
        );
        return _asList(res.data).map(LookupOption.fromJson).toList();
      });
}
