import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Real [AuthRepository] backed by dio. Maps every [DioException] to an
/// [AppException]; never lets a raw transport error leak to the UI.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  Map<String, dynamic> _asMap(Object? data) => (data as Map).cast<String, dynamic>();

  @override
  Future<LoginResult> login({required String email, required String password}) =>
      _guard(() async {
        final res = await _dio.post<Object?>(
          '/auth/login',
          data: {'email': email, 'password': password},
        );
        return LoginResult.fromJson(_asMap(res.data));
      });

  @override
  Future<RegisterResult> register({
    required String tenantName,
    required String slug,
    required String fullName,
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final res = await _dio.post<Object?>('/auth/register', data: {
          'tenantName': tenantName,
          'slug': slug,
          'fullName': fullName,
          'email': email,
          'password': password,
        });
        return RegisterResult.fromJson(_asMap(res.data));
      });

  @override
  Future<void> verifyEmail(String token) => _guard(() async {
        await _dio.post<Object?>('/auth/verify-email', data: {'token': token});
      });

  @override
  Future<void> forgotPassword(String email) => _guard(() async {
        await _dio.post<Object?>('/auth/forgot-password', data: {'email': email});
      });

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _guard(() async {
        await _dio.post<Object?>('/auth/reset-password',
            data: {'token': token, 'newPassword': newPassword});
      });

  @override
  Future<Tokens> acceptInvite({
    required String token,
    String? fullName,
    required String password,
  }) =>
      _guard(() async {
        final data = <String, dynamic>{'token': token, 'password': password};
        if (fullName != null) data['fullName'] = fullName;
        final res = await _dio.post<Object?>('/invites/accept', data: data);
        return Tokens.fromJson(_asMap(res.data));
      });

  @override
  Future<Tokens> switchTenant(String tenantId) => _guard(() async {
        final res = await _dio
            .post<Object?>('/auth/switch-tenant', data: {'tenantId': tenantId});
        return Tokens.fromJson(_asMap(res.data));
      });

  @override
  Future<Tokens> refresh(String refreshToken) => _guard(() async {
        final res = await _dio.post<Object?>('/auth/refresh',
            data: {'refreshToken': refreshToken});
        return Tokens.fromJson(_asMap(res.data));
      });

  @override
  Future<void> logout(String refreshToken) => _guard(() async {
        await _dio
            .post<Object?>('/auth/logout', data: {'refreshToken': refreshToken});
      });

  @override
  Future<Me> fetchMe() => _guard(() async {
        final res = await _dio.get<Object?>('/me');
        return Me.fromJson(_asMap(res.data));
      });
}
