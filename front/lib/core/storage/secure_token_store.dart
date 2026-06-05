import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists ONLY the opaque refresh token, in the platform secure store
/// (Keychain / Keystore / WebCrypto-backed). The access token is NEVER persisted
/// here — it lives in memory only ([AccessTokenStore]).
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'orbix_refresh_token';

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshKey);
}
