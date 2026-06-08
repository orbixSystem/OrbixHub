// Named params with private fields can't use initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import 'access_token_store.dart';
import 'token_refresh_service.dart';

/// Attaches the in-memory bearer on every request, and on a 401 for an
/// authenticated request triggers a single-flight refresh and replays the
/// original request once. If refresh fails, [onSessionExpired] is invoked so the
/// session layer can drop to unauthenticated and redirect to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required AccessTokenStore accessStore,
    required TokenRefreshService refreshService,
    required void Function() onSessionExpired,
  })  : _dio = dio,
        _accessStore = accessStore,
        _refreshService = refreshService,
        _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final AccessTokenStore _accessStore;
  final TokenRefreshService _refreshService;
  final void Function() _onSessionExpired;

  static const _retriedKey = 'orbix_retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _accessStore.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = req.extra[_retriedKey] == true;
    final hadBearer = req.headers.containsKey('Authorization');

    // Only authenticated requests are eligible for refresh-and-retry. Public
    // endpoints (login/refresh carry no bearer) fall through untouched, which
    // also prevents any refresh recursion.
    if (!isUnauthorized || alreadyRetried || !hadBearer) {
      return handler.next(err);
    }

    final refreshed = await _refreshService.refresh();
    if (!refreshed) {
      _onSessionExpired();
      return handler.next(err);
    }

    // Replay the original request once, with the new bearer.
    req.extra[_retriedKey] = true;
    req.headers['Authorization'] = 'Bearer ${_accessStore.token}';
    try {
      final response = await _dio.fetch<Object?>(req);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
