// Named params with private fields can't use initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'access_token_store.dart';
import 'refresh_token_store.dart';
import 'single_flight_refresher.dart';

/// Performs the token refresh and persists the new pair, wrapped in a
/// [SingleFlightRefresher] so concurrent 401s collapse into ONE refresh call.
///
/// Uses a BARE dio (no auth interceptor) so the refresh request can never
/// recurse back into the 401 handler.
///
/// The refresh token is read from the in-memory [RefreshTokenStore] (set at
/// login / bootstrap). The rotated token is written back to memory always, and
/// to [SecureTokenStore] ONLY when the session opted into "keep me logged in"
/// ([RefreshTokenStore.remember]). This keeps the mid-session 401 refresh
/// working even when the user did not opt into persistence.
class TokenRefreshService {
  TokenRefreshService({
    required Dio bareDio,
    required AccessTokenStore accessStore,
    required RefreshTokenStore refreshStore,
    required SecureTokenStore secureStore,
  })  : _bareDio = bareDio,
        _accessStore = accessStore,
        _refreshStore = refreshStore,
        _secureStore = secureStore {
    coordinator = SingleFlightRefresher(_perform);
  }

  final Dio _bareDio;
  final AccessTokenStore _accessStore;
  final RefreshTokenStore _refreshStore;
  final SecureTokenStore _secureStore;

  late final SingleFlightRefresher coordinator;

  /// Returns true if a fresh access token is now in [AccessTokenStore].
  Future<bool> refresh() => coordinator.refresh();

  Future<bool> _perform() async {
    final refreshToken = _refreshStore.token;
    if (refreshToken == null) return false;
    try {
      final res = await _bareDio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      _accessStore.set(data['accessToken'] as String);
      final rotated = data['refreshToken'] as String;
      _refreshStore.set(rotated);
      if (_refreshStore.remember) {
        await _secureStore.writeRefreshToken(rotated);
      }
      return true;
    } catch (_) {
      // Refresh family rejected → drop the whole session.
      _accessStore.clear();
      _refreshStore.clear();
      await _secureStore.clear();
      return false;
    }
  }
}
