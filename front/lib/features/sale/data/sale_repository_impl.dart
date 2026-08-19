import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/sale_models.dart';
import '../domain/sale_repository.dart';

/// [SaleRepository] real, sobre dio.
class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl(this._dio);

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
  Future<SalePage> listSales({
    String? status,
    String? customerId,
    String? q,
    String? from,
    String? to,
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>('/sales', queryParameters: {
          'status': ?status,
          'customerId': ?customerId,
          'q': ?q,
          'from': ?from,
          'to': ?to,
          'page': page,
        });
        return SalePage.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> getSale(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/sales/$id');
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> createSale(SaleDraft draft) => _guard(() async {
        final res = await _dio.post<Object?>('/sales', data: draft.toJson());
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> updateSale(
    String id, {
    String? customerId,
    List<SaleItemDraft>? items,
    double? discount,
    String? description,
  }) =>
      _guard(() async {
        final res = await _dio.patch<Object?>('/sales/$id', data: {
          // `customerId: null` DESVINCULA, então a chave só é OMITIDA quando o
          // chamador não quer tocar no cliente.
          'customerId': ?customerId,
          'items': ?items?.map((i) => i.toJson()).toList(),
          'discount': ?discount,
          // String vazia é intencional (apaga a observação) — por isso o teste é
          // por `null`, não por `isNotEmpty`.
          'description': ?description,
        });
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<Sale> cancelSale(String id, {String? reason}) => _guard(() async {
        final res = await _dio.post<Object?>('/sales/$id/cancel', data: {
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        });
        return Sale.fromJson(_asMap(res.data));
      });

  @override
  Future<SaleFiscalResult> emitInvoice(String id) => _guard(() async {
        // A nota é do módulo `invoice` (POST /invoices { saleId }); o backend
        // espelha o snapshot em `sale.fiscal_status`. Aqui só traduzimos o
        // status da nota para o vocabulário do snapshot.
        final res =
            await _dio.post<Object?>('/invoices', data: {'saleId': id});
        final map = _asMap(res.data);
        final status = map['status'] as String? ?? 'processing';
        return SaleFiscalResult(
          status: switch (status) {
            'authorized' => 'emitida',
            'rejected' || 'error' => 'rejeitada',
            _ => 'processando',
          },
          externalId: map['external_id'] as String?,
          message: map['rejection_reason'] as String?,
        );
      });
}
