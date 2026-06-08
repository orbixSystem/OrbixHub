import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/team_models.dart';
import '../domain/team_repository.dart';

/// Real [TeamRepository] backed by dio.
class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<List<RoleOption>> roles() => _guard(() async {
        final res = await _dio.get<Object?>('/roles');
        final list = (res.data as List).cast<Map<String, dynamic>>();
        return list.map(RoleOption.fromJson).toList();
      });

  @override
  Future<List<Employee>> employees() => _guard(() async {
        final res = await _dio.get<Object?>('/employees');
        final list = (res.data as List).cast<Map<String, dynamic>>();
        return list.map(Employee.fromJson).toList();
      });

  @override
  Future<List<PendingInvite>> pendingInvites() => _guard(() async {
        final res = await _dio.get<Object?>('/invites');
        final list = (res.data as List).cast<Map<String, dynamic>>();
        return list.map(PendingInvite.fromJson).toList();
      });

  @override
  Future<void> invite({
    required String email,
    required String role,
    required String expiresIn,
    required String currentPassword,
    String? accessExpiresAt,
  }) =>
      _guard(() async {
        await _dio.post<Object?>('/tenants/invites', data: {
          'email': email,
          'role': role,
          'expiresIn': expiresIn,
          'currentPassword': currentPassword,
          'accessExpiresAt': ?accessExpiresAt,
        });
      });

  @override
  Future<void> resendInvite(
    String inviteId, {
    required String expiresIn,
    required String currentPassword,
  }) =>
      _guard(() async {
        await _dio.post<Object?>('/invites/$inviteId/resend', data: {
          'currentPassword': currentPassword,
          'expiresIn': expiresIn,
        });
      });

  @override
  Future<void> cancelInvite(String inviteId) => _guard(() async {
        await _dio.delete<Object?>('/invites/$inviteId');
      });

  @override
  Future<void> changeRole({
    required String membershipId,
    required String role,
    required String currentPassword,
  }) =>
      _guard(() async {
        await _dio.patch<Object?>('/employees/$membershipId/role', data: {
          'role': role,
          'currentPassword': currentPassword,
        });
      });

  @override
  Future<void> deactivate({
    required String membershipId,
    required String currentPassword,
  }) =>
      _guard(() async {
        await _dio.post<Object?>('/employees/$membershipId/deactivate', data: {
          'currentPassword': currentPassword,
        });
      });

  @override
  Future<void> activate({
    required String membershipId,
    required String currentPassword,
  }) =>
      _guard(() async {
        await _dio.post<Object?>('/employees/$membershipId/activate', data: {
          'currentPassword': currentPassword,
        });
      });
}
