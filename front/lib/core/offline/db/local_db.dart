import 'dart:convert';

import 'package:drift/drift.dart';

// Abertura por plataforma: nativo (dart:io + SQLCipher) ou stub web (lança).
// A web é online-only — o stub garante que `local_db.dart` compile no build web
// sem arrastar `dart:io`/FFI; nada do offline é chamado lá (guardas `kIsWeb`).
import 'db_stub.dart' if (dart.library.io) 'db_native.dart' as platform;

part 'local_db.g.dart';

/// Espelho local (row-store genérico) de uma entidade puxada do servidor. O
/// [payload] é o MESMO JSON cru da API — os repositórios LocalFirst (B8) o
/// desserializam com o `fromJson` do domínio; este banco não conhece domínio.
class EntityRows extends Table {
  TextColumn get entity => text()(); // 'customer', 'service_order', ...
  TextColumn get id => text()();
  TextColumn get payload => text()(); // json cru da API
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entity, id};
}

/// Fila de saída (outbox): mutações locais aguardando push. S1 — carrega a
/// autoria ([authorUserId]) para o engine só empurrar o que é DESTE usuário e
/// para idempotência por autor. [seq] impõe a ordem de aplicação.
class Outbox extends Table {
  TextColumn get clientMutationId => text().unique()();
  TextColumn get authorUserId => text()(); // S1
  TextColumn get entity => text()();
  TextColumn get op => text()();
  TextColumn get payload => text()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  // pending | applied | discarded | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get message => text().nullable()();
  IntColumn get seq => integer().autoIncrement()(); // ordem de aplicação
}

/// Cursor de sincronização por entidade (ponto do último pull).
class SyncState extends Table {
  TextColumn get entity => text()();
  TextColumn get cursorTs => text().nullable()();
  TextColumn get cursorId => text().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}

/// S6 — anexos (fotos da OS) pendentes de upload guardados como BLOB DENTRO do
/// banco cifrado; nunca em arquivo solto no disco.
class PendingUploads extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  BlobColumn get bytes => blob()();
  TextColumn get filename => text()();
  TextColumn get contentType => text()();
  TextColumn get caption => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Uma mutação local pendente de push (enfileirada no [Outbox]). Tipo genérico,
/// sem domínio: [payload] é o JSON cru que o B7 (push) enviará à API.
class LocalMutation {
  const LocalMutation({
    required this.clientMutationId,
    required this.authorUserId,
    required this.entity,
    required this.op,
    required this.payload,
    required this.clientUpdatedAt,
  });

  final String clientMutationId;
  final String authorUserId;
  final String entity;
  final String op; // create | update | delete | ...
  final String payload;
  final DateTime clientUpdatedAt;
}

/// Banco local offline-first (por tenant). Row-store genérico do pull + outbox
/// de mutações + cursores de sync + anexos (BLOB) pendentes de upload. O wrapper
/// é agnóstico de domínio: guarda/entrega JSON cru; quem parseia é o B8.
@DriftDatabase(tables: [EntityRows, Outbox, SyncState, PendingUploads])
class LocalDb extends _$LocalDb {
  LocalDb(super.executor);

  @override
  int get schemaVersion => 1;

  /// Guarda `DateTime` como texto ISO-8601 em UTC (não como unix-seconds). Assim
  /// o round-trip preserva o instante em UTC e a precisão de milissegundos — sem
  /// o footgun do modo padrão, que materializa em horário LOCAL. Crucial para as
  /// comparações de timestamp do sync (last-write-wins, B8) e p/ S3.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  // --- Cache por tenant / ciclo de vida ---------------------------------

  static final Map<String, LocalDb> _instances = {};

  /// Abre (ou devolve do cache) o banco cifrado do [tenantId] — arquivo
  /// `orbix_<tenantId>.db`. Singleton por tenant: abrir duas vezes devolve a
  /// MESMA instância. Na web lança (offline é `!kIsWeb`).
  static LocalDb forTenant(String tenantId) => _instances.putIfAbsent(
        tenantId,
        () => LocalDb(platform.openTenantExecutor(tenantId)),
      );

  /// S5 — revogação da réplica: fecha a instância cacheada (se houver) e apaga
  /// o arquivo do tenant e seus irmãos WAL/SHM.
  static Future<void> deleteDbForTenant(String tenantId) async {
    final cached = _instances.remove(tenantId);
    await cached?.close();
    await platform.deleteTenantFiles(tenantId);
  }

  /// Fecha todas as instâncias abertas (logout/testes) e limpa o cache.
  static Future<void> closeAll() async {
    final dbs = _instances.values.toList(growable: false);
    _instances.clear();
    for (final db in dbs) {
      await db.close();
    }
  }

  // --- Row-store (espelho do pull) --------------------------------------

  /// Insere/atualiza (upsert por {entity,id}) as linhas de uma entidade. O
  /// [rows] traz o JSON cru da API — preservado byte a byte.
  Future<void> upsertRows(
    String entity,
    List<({String id, String payload, DateTime updatedAt})> rows,
  ) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(entityRows, [
        for (final r in rows)
          EntityRowsCompanion.insert(
            entity: entity,
            id: r.id,
            payload: r.payload,
            updatedAt: r.updatedAt,
          ),
      ]);
    });
  }

  /// Todas as linhas locais de uma entidade (JSON cru em `.payload`).
  Future<List<EntityRow>> rowsOf(String entity) =>
      (select(entityRows)..where((t) => t.entity.equals(entity))).get();

  // --- Outbox -----------------------------------------------------------

  /// Enfileira uma mutação local para push (status inicial `pending`).
  Future<void> enqueue(LocalMutation m) => into(outbox).insert(
        OutboxCompanion.insert(
          clientMutationId: m.clientMutationId,
          authorUserId: m.authorUserId,
          entity: m.entity,
          op: m.op,
          payload: m.payload,
          clientUpdatedAt: m.clientUpdatedAt,
        ),
      );

  /// Mutações `pending` DESTE autor (S1), na ordem de aplicação (por `seq`).
  Future<List<OutboxData>> pendingFor(String authorUserId) =>
      (select(outbox)
            ..where((t) =>
                t.authorUserId.equals(authorUserId) & t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
          .get();

  /// Transição de status de uma entrada do outbox (`applied`/`discarded`/
  /// `failed`), opcionalmente com uma [message] (ex.: motivo da falha).
  Future<void> markOutbox(
    String clientMutationId,
    String status, [
    String? message,
  ]) async {
    await (update(outbox)
          ..where((t) => t.clientMutationId.equals(clientMutationId)))
        .write(OutboxCompanion(status: Value(status), message: Value(message)));
  }

  /// Ids de linhas de [entity] com mutação local **ainda não confirmada** pelo
  /// servidor (`pending` — na fila — ou `failed` — recusada). São as linhas
  /// "sujas": elas podem não existir no servidor (create offline) ou ter uma
  /// edição que ele ainda não viu. Os repositórios LocalFirst (B8) usam isto para
  /// escolher o caminho LOCAL mesmo com rede — ir ao servidor daria 404 (ou
  /// mostraria um estado velho por cima da edição local).
  Future<Set<String>> unsyncedIds(String entity) async {
    final rows = await (select(outbox)
          ..where((t) =>
              t.entity.equals(entity) &
              (t.status.equals('pending') | t.status.equals('failed'))))
        .get();
    final ids = <String>{};
    for (final r in rows) {
      final id = (jsonDecode(r.payload) as Map<String, dynamic>)['id'];
      if (id is String) ids.add(id);
    }
    return ids;
  }

  /// `true` se [id] de [entity] tem mutação local não confirmada (ver [unsyncedIds]).
  Future<bool> hasPendingFor(String entity, String id) async =>
      (await unsyncedIds(entity)).contains(id);

  /// Contadores de pendentes p/ o indicador (B2): `mine` = deste autor,
  /// `others` = de outros autores (device compartilhado).
  Future<({int mine, int others})> pendingCounts(String authorUserId) async {
    final mineExp = countAll(filter: outbox.authorUserId.equals(authorUserId));
    final othersExp =
        countAll(filter: outbox.authorUserId.equals(authorUserId).not());
    final q = selectOnly(outbox)
      ..where(outbox.status.equals('pending'))
      ..addColumns([mineExp, othersExp]);
    final row = await q.getSingle();
    return (mine: row.read(mineExp) ?? 0, others: row.read(othersExp) ?? 0);
  }

  // --- Cursores ---------------------------------------------------------

  /// Cursor de sync de uma entidade, ou `null` se nunca puxada.
  Future<SyncStateData?> cursorFor(String entity) =>
      (select(syncState)..where((t) => t.entity.equals(entity)))
          .getSingleOrNull();

  /// Salva (upsert) o cursor de uma entidade após um pull.
  Future<void> saveCursor(String entity, {String? ts, String? id}) =>
      into(syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(
          entity: entity,
          cursorTs: Value(ts),
          cursorId: Value(id),
        ),
      );

  // --- Anexos pendentes (S6) --------------------------------------------

  /// Guarda um anexo (foto) como BLOB DENTRO do banco cifrado, pendente de
  /// upload — nunca em arquivo solto no disco.
  Future<void> addPendingUpload({
    required String id,
    required String orderId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String? caption,
  }) =>
      into(pendingUploads).insert(
        PendingUploadsCompanion.insert(
          id: id,
          orderId: orderId,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
          caption: Value(caption),
        ),
      );

  /// Todos os anexos pendentes de upload.
  Future<List<PendingUpload>> listPendingUploads() =>
      select(pendingUploads).get();

  /// Remove um anexo pendente (após upload bem-sucedido).
  Future<void> deletePendingUpload(String id) async {
    await (delete(pendingUploads)..where((t) => t.id.equals(id))).go();
  }
}
