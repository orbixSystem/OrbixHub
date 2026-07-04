import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists ONLY the opaque refresh token, in the platform secure store
/// (Keychain / Keystore / WebCrypto-backed). The access token is NEVER persisted
/// here — it lives in memory only ([AccessTokenStore]).
///
/// macOS: usa o Keychain LEGADO (`usesDataProtectionKeychain: false`). O
/// data-protection keychain (padrão) exige a entitlement `keychain-access-groups`,
/// que por sua vez exige assinatura com certificado de desenvolvedor — com
/// assinatura ad-hoc (dev local) isso falha com -34018 (errSecMissingEntitlement).
/// O Keychain legado não exige a entitlement e funciona sem certificado. Só
/// afeta macOS (`mOptions`); iOS/Android/web usam suas próprias opções. Para um
/// release macOS assinado (Keychain Sharing + time), volte para `true`.
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            );

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'orbix_refresh_token';

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshKey, value: token);

  Future<void> clear() => _storage.delete(key: _refreshKey);
}
