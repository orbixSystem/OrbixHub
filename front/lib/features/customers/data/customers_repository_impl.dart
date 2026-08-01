import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/customers_models.dart';
import '../domain/customers_repository.dart';

/// Real [CustomersRepository] backed by dio.
class CustomersRepositoryImpl implements CustomersRepository {
  CustomersRepositoryImpl(this._dio);

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
  Future<CustomersConfig> fetchConfig() => _guard(() async {
        final res = await _dio.get<Object?>('/customers/config');
        return CustomersConfig.fromJson(_asMap(res.data));
      });

  @override
  Future<CustomerPage> listCustomers({
    String? q,
    String status = 'active',
    String sort = 'recent',
    int page = 1,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/customers',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            'status': status,
            'sort': sort,
            'page': page,
          },
        );
        return CustomerPage.fromJson(_asMap(res.data));
      });

  @override
  Future<Customer> getCustomer(String id) => _guard(() async {
        final res = await _dio.get<Object?>('/customers/$id');
        return Customer.fromJson(_asMap(res.data));
      });

  @override
  Future<Customer> createCustomer(CustomerDraft draft) => _guard(() async {
        final res =
            await _dio.post<Object?>('/customers', data: draft.toJson());
        return Customer.fromJson(_asMap(res.data));
      });

  @override
  Future<Customer> updateCustomer(String id, CustomerDraft draft) =>
      _guard(() async {
        final res =
            await _dio.patch<Object?>('/customers/$id', data: draft.toJson());
        return Customer.fromJson(_asMap(res.data));
      });

  @override
  Future<Customer> archiveCustomer(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/customers/$id/archive');
        return Customer.fromJson(_asMap(res.data));
      });

  @override
  Future<Customer> unarchiveCustomer(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/customers/$id/unarchive');
        return Customer.fromJson(_asMap(res.data));
      });

  @override
  Future<Customer> deleteCustomer(String id) => _guard(() async {
        final res = await _dio.delete<Object?>('/customers/$id');
        return Customer.fromJson(_asMap(res.data));
      });

  @override
  Future<SubjectPage> listSubjects({
    String? q,
    String? customerId,
    String status = 'active',
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/subjects',
          queryParameters: {
            if (q != null && q.isNotEmpty) 'q': q,
            'customerId': ?customerId,
            'status': status,
          },
        );
        return SubjectPage.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> createSubject(String customerId, SubjectDraft draft) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/customers/$customerId/subjects',
          data: draft.toJson(),
        );
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> updateSubject(String id, SubjectDraft draft) =>
      _guard(() async {
        final res =
            await _dio.patch<Object?>('/subjects/$id', data: draft.toJson());
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> archiveSubject(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/subjects/$id/archive');
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> unarchiveSubject(String id) => _guard(() async {
        final res = await _dio.post<Object?>('/subjects/$id/unarchive');
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> setSubjectPhoto(
    String id, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) =>
      _guard(() async {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(contentType),
          ),
        });
        final res = await _dio.post<Object?>('/subjects/$id/photo', data: form);
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> removeSubjectPhoto(String id) => _guard(() async {
        final res = await _dio.delete<Object?>('/subjects/$id/photo');
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<Subject> deleteSubject(String id) => _guard(() async {
        final res = await _dio.delete<Object?>('/subjects/$id');
        return Subject.fromJson(_asMap(res.data));
      });

  @override
  Future<List<SubjectHistoryEntry>> subjectHistory(String id) =>
      _guard(() async {
        final res = await _dio.get<Object?>('/subjects/$id/history');
        return _asList(res.data).map(SubjectHistoryEntry.fromJson).toList();
      });

  @override
  Future<List<SubjectHistoryEntry>> customerHistory(
    String customerId, {
    String? subjectId,
  }) =>
      _guard(() async {
        final res = await _dio.get<Object?>(
          '/customers/$customerId/history',
          queryParameters: {'subjectId': ?subjectId},
        );
        return _asList(res.data).map(SubjectHistoryEntry.fromJson).toList();
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

  @override
  Future<PlateInfo> plateLookup(String plate) => _guard(() async {
        final res = await _dio.get<Object?>('/customers/plates/$plate');
        return PlateInfo.fromJson(_asMap(res.data));
      });

  @override
  Future<PlateQuota> plateUsage() => _guard(() async {
        final res = await _dio.get<Object?>('/customers/plates/usage');
        return PlateQuota.fromJson(_asMap(res.data));
      });
}
