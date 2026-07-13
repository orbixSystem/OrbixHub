import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';

/// S4 — hash de senha local (login offline) com **argon2id**, 64 MB de memória
/// e 3 iterações. O hash NUNCA sai do dispositivo e a senha em claro NUNCA é
/// persistida: só o encoded PHC (que carrega parâmetros + salt aleatório).
///
/// **Implementação: `hashlib` (Dart puro), não `sodium_libs`.** O `sodium_libs`
/// depende da libsodium nativa, que não é carregada na VM do `flutter test`
/// (sem plugins/native assets) — o hash ficaria não testável — e o pacote está
/// descontinuado no pub. O `hashlib` roda em todos os alvos (incl. web, embora
/// lá o offline esteja desligado) e mantém os MESMOS parâmetros de custo
/// (`Argon2Security.good` = m=65536 KB, t=3, p=4). Custo medido: ~0,7 s por
/// hash em JIT nesta máquina — dentro do esperado para argon2id de 64 MB.
class PasswordHasher {
  const PasswordHasher();

  /// Memória em KB (64 MB) — NÃO reduza (S4).
  static const memoryKb = 1 << 16;

  /// Iterações (t) — NÃO reduza (S4).
  static const iterations = 3;

  /// Paralelismo (p).
  static const parallelism = 4;

  /// Bytes de salt aleatório por credencial.
  static const saltBytes = 16;

  static const _security = Argon2Security(
    'orbix',
    m: memoryKb,
    t: iterations,
    p: parallelism,
  );

  /// Salt aleatório (CSPRNG) de [saltBytes] bytes.
  static Uint8List newSalt() {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltBytes, (_) => rnd.nextInt(256)),
    );
  }

  /// Hash argon2id de [password], no formato PHC
  /// (`$argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>`). Sem [salt], gera um
  /// aleatório — dois hashes da mesma senha são diferentes.
  String hash(String password, [List<int>? salt]) {
    return argon2id(
      _bytes(password),
      salt ?? newSalt(),
      security: _security,
      hashLength: 32,
    ).encoded();
  }

  /// `true` se [password] gera o [encoded] (PHC) — parâmetros e salt vêm do
  /// próprio encoded, então hashes antigos continuam verificáveis se algum dia
  /// o custo subir. Encoded corrompido/desconhecido ⇒ `false` (nunca lança).
  bool verify(String password, String encoded) {
    try {
      return argon2Verify(encoded, _bytes(password));
    } catch (_) {
      return false;
    }
  }

  List<int> _bytes(String password) => utf8.encode(password);
}
