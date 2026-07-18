import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'db_key_store.dart';

/// Abertura nativa (desktop/mobile) do banco local cifrado (SQLCipher).
///
/// Resolvido por import condicional em `local_db.dart` só quando `dart.library.io`
/// existe — a web usa `db_stub.dart`. Expõe também dois "seams" de teste
/// ([supportDirOverride], [executorFactory]) porque `flutter test` roda numa VM
/// sem os platform channels de `path_provider`/`flutter_secure_storage` e sem a
/// lib SQLCipher — a verificação real da cifra fica pro B10 no Windows.

/// Sobrescreve o diretório-base do banco. Produção: `null` (usa o
/// application-support dir do `path_provider`). Testes apontam para um dir
/// temporário real.
Future<Directory> Function()? supportDirOverride;

/// Sobrescreve como o executor por-tenant é construído. Produção: `null` (abre
/// um arquivo cifrado com a chave do [DbKeyStore]). Testes injetam um executor
/// simples (arquivo em claro / memória), pois SQLCipher não está disponível na
/// VM de teste.
Future<QueryExecutor> Function(String tenantId, File file)? executorFactory;

/// Setup de plataforma chamado uma vez no bootstrap (main isolate).
///
/// - Android: workaround para abrir `libsqlcipher.so` em versões antigas.
/// - **Apple (macOS/iOS): força o carregamento do SQLCipher.** O app embute
///   TANTO `SQLCipher.framework` quanto um `sqlite3.framework` (SQLite PURO, sem
///   cifra). Sem override, o `package:sqlite3` abre o framework puro (ou o
///   `libsqlite3` do sistema) e o banco seria gravado SEM cifra — o guard em
///   [_encryptedExecutor] então aborta com "SQLCipher indisponível". Apontar o
///   `open` para `SQLCipher.framework/SQLCipher` resolve (resolvido via @rpath
///   do bundle). Windows/Linux já carregam o SQLCipher do `sqlcipher_flutter_libs`.
Future<void> initOfflineDb() async {
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
  if (Platform.isMacOS) {
    open.overrideFor(OperatingSystem.macOS, _openSqlCipherApple);
  } else if (Platform.isIOS) {
    open.overrideFor(OperatingSystem.iOS, _openSqlCipherApple);
  }
}

/// Carrega o binário do SQLCipher embutido no bundle Apple (macOS/iOS).
DynamicLibrary _openSqlCipherApple() =>
    DynamicLibrary.open('SQLCipher.framework/SQLCipher');

Future<Directory> _supportDir() async {
  final override = supportDirOverride;
  if (override != null) return override();
  return getApplicationSupportDirectory();
}

/// Arquivo `orbix_<tenantId>.db` (um por tenant) sob o diretório-base.
File _dbFile(Directory dir, String tenantId) =>
    File(p.join(dir.path, 'orbix_$tenantId.db'));

/// Executor por-tenant (aberto preguiçosamente): resolve o diretório, aplica a
/// chave de cifra e abre o arquivo num isolate de background.
QueryExecutor openTenantExecutor(String tenantId) {
  return LazyDatabase(() async {
    final dir = await _supportDir();
    await dir.create(recursive: true);
    final file = _dbFile(dir, tenantId);
    final make = executorFactory ?? _encryptedExecutor;
    return make(tenantId, file);
  });
}

Future<QueryExecutor> _encryptedExecutor(String tenantId, File file) async {
  final key = await DbKeyStore().getOrCreate();
  return NativeDatabase.createInBackground(
    file,
    setup: (raw) {
      // S6 — cifra AES via SQLCipher. `x'<hex>'` = chave crua (sem KDF sobre o
      // texto), já que geramos 32 bytes aleatórios.
      raw.execute("PRAGMA key = \"x'$key'\";");
      // Falha cedo se a lib linkada NÃO for SQLCipher (senão o PRAGMA key é
      // ignorado em silêncio e gravaríamos em claro).
      final cipher = raw.select('PRAGMA cipher_version;');
      if (cipher.isEmpty) {
        throw StateError(
          'SQLCipher indisponível: o banco local seria gravado sem cifra.',
        );
      }
    },
  );
}

/// S5 — revogação da réplica: remove o arquivo do tenant e seus irmãos WAL/SHM.
Future<void> deleteTenantFiles(String tenantId) async {
  final dir = await _supportDir();
  final base = _dbFile(dir, tenantId).path;
  for (final suffix in const ['', '-wal', '-shm']) {
    final f = File('$base$suffix');
    if (await f.exists()) await f.delete();
  }
}
