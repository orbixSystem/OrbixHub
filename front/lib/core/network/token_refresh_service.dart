// Named params with private fields can't use initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'access_token_store.dart';
import 'single_flight_refresher.dart';

/// Performs the token refresh and persists the new pair, wrapped in a
/// [SingleFlightRefresher] so concurrent 401s collapse into ONE refresh call.
///
/// Uses a BARE dio (no auth interceptor) so the refresh request can never
/// recurse back into the 401 handler.
class TokenRefreshService {
  TokenRefreshService({
    required Dio bareDio,
    required AccessTokenStore accessStore,
    required SecureTokenStore secureStore,
  })  : _bareDio = bareDio,
        _accessStore = accessStore,
        _secureStore = secureStore {
    coordinator = SingleFlightRefresher(_perform);
  }

  final Dio _bareDio;
  final AccessTokenStore _accessStore;
  final SecureTokenStore _secureStore;

  late final SingleFlightRefresher coordinator;

  /// Returns true if a fresh access token is now in [AccessTokenStore].
  Future<bool> refresh() => coordinator.refresh();

  Future<bool> _perform() async {
    final refreshToken = await _secureStore.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await _bareDio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = (res.data as Map).cast<String, dynamic>();
      _accessStore.set(data['accessToken'] as String);
      await _secureStore.writeRefreshToken(data['refreshToken'] as String);
      return true;
    } catch (_) {
      // Refresh family rejected → drop the whole session.
      _accessStore.clear();
      await _secureStore.clear();
      return false;
    }
  }
}
