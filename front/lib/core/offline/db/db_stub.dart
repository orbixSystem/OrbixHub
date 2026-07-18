import 'package:drift/drift.dart';

/// Stub web do abridor do banco local. A web é online-only: o offline nunca é
/// acionado lá (guardas `kIsWeb` em `di.dart`/repos), então estas funções só
/// existem para o import condicional resolver e o build web não arrastar
/// `dart:io`/FFI. Chamá-las na web é um erro de programação.

const _msg = 'Banco local offline indisponível na web (online-only).';

QueryExecutor openTenantExecutor(String tenantId) =>
    throw UnsupportedError(_msg);

Future<void> deleteTenantFiles(String tenantId) async =>
    throw UnsupportedError(_msg);

/// No-op na web: não há SQLCipher a inicializar.
Future<void> initOfflineDb() async {}
