import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// S5/S6 — chave de cifra do banco local (SQLCipher), por dispositivo.
///
/// Gera UMA vez 32 bytes aleatórios seguros (`Random.secure`), guarda o valor
/// hex no `FlutterSecureStorage` sob [storageKey] e reusa daí em diante. A chave
/// nunca sai do secure storage do device; é aplicada via `PRAGMA key` na
/// abertura do banco. Apagar a chave (revogação) torna a réplica ilegível.
class DbKeyStore {
  DbKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

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
