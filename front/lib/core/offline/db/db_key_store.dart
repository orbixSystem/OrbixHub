import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// S5/S6 — chave de cifra do banco local (SQLCipher), por dispositivo.
///
/// Gera UMA vez 32 bytes aleatórios seguros (`Random.secure`), guarda o valor
/// hex no `FlutterSecureStorage` sob [storageKey] e reusa daí em diante. A chave
/// nunca sai do secure storage do device; é aplicada via `PRAGMA key` na
/// abertura do banco. Apagar a chave (revogação) torna a réplica ilegível.
///
/// macOS: usa o Keychain LEGADO (`usesDataProtectionKeychain: false`), igual ao
/// [SecureTokenStore]. O data-protection keychain (padrão) exige a entitlement
/// `keychain-access-groups`, que exige assinatura com certificado — com ad-hoc
/// signing (dev local) falha com -34018 (errSecMissingEntitlement) e derrubava o
/// login ao abrir o banco offline. O keychain legado funciona sem certificado.
class DbKeyStore {
  DbKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            );

  static const storageKey = 'orbix_db_key';

  final FlutterSecureStorage _storage;

  /// Retorna a chave hex persistida, gerando-a (32 bytes seguros) na primeira
  /// chamada. Idempotente: chamadas seguintes devolvem sempre a mesma chave.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: storageKey, value: hex);
    return hex;
  }
}
