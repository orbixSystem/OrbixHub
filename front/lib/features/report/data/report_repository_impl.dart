import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';

/// [ReportRepository] real, sobre dio. Cada chamada bate em `/report/*`
/// (gated no backend por módulo `report` + `report.read`). Membros vêm de
/// `/employees/assignable` (mesma rota do dropdown da OS — liberada p/
/// qualquer membro ativo, sem exigir users.manage).
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._dio);

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

  List<dynamic> _asList(Object? data) => (data as List?) ?? const [];

  @override
  Future<OsOperationalReport> osReport({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
    int page = 1,
    int pageSize = 50,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/os',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (assignedTo != null && assignedTo.isNotEmpty)
              'assignedTo': assignedTo,
            if (status != null && status.isNotEmpty) 'status': status,
            if (q != null && q.isNotEmpty) 'q': q,
            'sort': sort,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return OsOperationalReport.fromJson(_asMap(res.data));
      });

  @override
  Future<Uint8List> osCsv({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
  }) =>
      _guard(() async {
        final res = await _dio.get<List<int>>(
          '/report/os.csv',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (assignedTo != null && assignedTo.isNotEmpty)
              'assignedTo': assignedTo,
            if (status != null && status.isNotEmpty) 'status': status,
            if (q != null && q.isNotEmpty) 'q': q,
            'sort': sort,
          },
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data ?? const []);
      });

  @override
  Future<Uint8List> osPdf({
    required ReportRange range,
    String? assignedTo,
    String? status,
    String? q,
    String sort = 'recent',
    ReportExportCompany? company,
  }) =>
      _guard(() async {
        final res = await _dio.get<List<int>>(
          '/report/os.pdf',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (assignedTo != null && assignedTo.isNotEmpty)
              'assignedTo': assignedTo,
            if (status != null && status.isNotEmpty) 'status': status,
            if (q != null && q.isNotEmpty) 'q': q,
            'sort': sort,
            if (company != null) 'companyName': company.name,
            if (company?.legalName != null && company!.legalName!.isNotEmpty)
              'companyLegalName': company.legalName,
            if (company?.cnpj != null && company!.cnpj!.isNotEmpty)
              'companyCnpj': company.cnpj,
          },
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data ?? const []);
      });

  @override
  Future<RevenueReport> revenue({required ReportRange range}) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/revenue',
          queryParameters: {'from': range.fromIso, 'to': range.toIso},
        );
        return RevenueReport.fromJson(_asMap(res.data));
      });

  @override
  Future<TeamReport> team({required ReportRange range}) => _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/team',
          queryParameters: {'from': range.fromIso, 'to': range.toIso},
        );
        return TeamReport.fromJson(_asMap(res.data));
      });

  @override
  Future<TopItemsReport> topItems({
    required ReportRange range,
    String? kind,
    int? limit,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/top-items',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (kind != null && kind.isNotEmpty) 'kind': kind,
            'limit': ?limit,
          },
        );
        return TopItemsReport.fromJson(_asMap(res.data));
      });

  @override
  Future<InventoryReport> inventory({
    int page = 1,
    int pageSize = 50,
    String? q,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/inventory',
          queryParameters: {
            'page': page,
            'pageSize': pageSize,
            if (q != null && q.isNotEmpty) 'q': q,
          },
        );
        return InventoryReport.fromJson(_asMap(res.data));
      });

  @override
  Future<Uint8List> inventoryCsv({String? q}) => _guard(() async {
        final res = await _dio.get<List<int>>(
          '/report/inventory.csv',
          queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data ?? const []);
      });

  @override
  Future<Uint8List> inventoryPdf({
    ReportExportCompany? company,
    String? q,
  }) =>
      _guard(() async {
        final res = await _dio.get<List<int>>(
          '/report/inventory.pdf',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            if (company != null) 'companyName': company.name,
            if (company?.legalName != null && company!.legalName!.isNotEmpty)
              'companyLegalName': company.legalName,
            if (company?.cnpj != null && company!.cnpj!.isNotEmpty)
              'companyCnpj': company.cnpj,
          },
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data ?? const []);
      });

  @override
  Future<CustomersReport> customers({
    required ReportRange range,
    int page = 1,
    int pageSize = 50,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/customers',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            'page': page,
            'pageSize': pageSize,
          },
        );
        return CustomersReport.fromJson(_asMap(res.data));
      });

  @override
  Future<Uint8List> customersCsv({required ReportRange range}) =>
      _guard(() async {
        final res = await _dio.get<List<int>>(
          '/report/customers.csv',
          queryParameters: {'from': range.fromIso, 'to': range.toIso},
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data ?? const []);
      });

  @override
  Future<Uint8List> customersPdf({
    required ReportRange range,
    ReportExportCompany? company,
  }) =>
      _guard(() async {
        final res = await _dio.get<List<int>>(
          '/report/customers.pdf',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (company != null) 'companyName': company.name,
            if (company?.legalName != null && company!.legalName!.isNotEmpty)
              'companyLegalName': company.legalName,
            if (company?.cnpj != null && company!.cnpj!.isNotEmpty)
              'companyCnpj': company.cnpj,
          },
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data ?? const []);
      });

  @override
  Future<SalesLedger> salesLedger({
    required ReportRange range,
    String? type,
    String? paymentStatus,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/sales',
          queryParameters: {
            'from': range.fromIso,
            'to': range.toIso,
            if (type != null && type.isNotEmpty) 'type': type,
            if (paymentStatus != null && paymentStatus.isNotEmpty)
              'paymentStatus': paymentStatus,
          },
        );
        return SalesLedger.fromJson(_asMap(res.data));
      });

  @override
  Future<List<ReportMemberOption>> members() => _guard(() async {
        final res = await _dio.get<Object?>('/employees/assignable');
        return _asList(res.data).map((m) {
          final id =
              (m['userId'] ?? m['membershipId'] ?? m['id'])?.toString();
          final name =
              (m['fullName'] ?? m['name'] ?? m['email'] ?? id)?.toString();
          return ReportMemberOption(id: id ?? '', name: name ?? id ?? '');
        }).where((m) => m.id.isNotEmpty).toList();
      });
}
