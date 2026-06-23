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
          },
        );
        return OsOperationalReport.fromJson(_asMap(res.data));
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
  Future<InventoryReport> inventory() => _guard(() async {
        final res = await _dio.get<Object?>('/report/inventory');
        return InventoryReport.fromJson(_asMap(res.data));
      });

  @override
  Future<CustomersReport> customers({required ReportRange range}) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/report/customers',
          queryParameters: {'from': range.fromIso, 'to': range.toIso},
        );
        return CustomersReport.fromJson(_asMap(res.data));
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
