import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbixhub_front/core/offline/db/db_key_store.dart';
import 'package:orbixhub_front/core/offline/db/db_native.dart' as db_native;
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:path/path.dart' as p;

/// B5 — banco local drift (row-store + outbox + cursores + anexos). Roda em
/// `NativeDatabase.memory()` (sqlite em memória, sem SQLCipher — a verificação
/// real da cifra é do B10 no Windows). Cobre o round-trip de payload cru,
/// ordenação do outbox por seq, transições de status, cursores e S5 (delete).
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

DateTime _ts(int day) => DateTime.utc(2026, 7, day);

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  tearDown(() async {
    db_native.supportDirOverride = null;
    db_native.executorFactory = null;
    await LocalDb.closeAll();
  });

  group('EntityRows row-store', () {
    test('upsertRows stores rows; rowsOf returns them with JSON preserved',
        () async {
      final db = _memDb();
      addTearDown(db.close);
      const p1 = '{"id":"c1","name":"Ana","plate":"ABC1D23"}';
      const p2 = '{"id":"c2","name":"Bruno"}';

      await db.upsertRows('customer', [
        (id: 'c1', payload: p1, updatedAt: _ts(1)),
        (id: 'c2', payload: p2, updatedAt: _ts(2)),
      ]);

      final rows = await db.rowsOf('customer');
      expect(rows.map((r) => r.id).toSet(), {'c1', 'c2'});
      final c1 = rows.firstWhere((r) => r.id == 'c1');
      expect(c1.payload, p1, reason: 'payload is the raw API JSON, untouched');
    });

    test('upsertRows replaces a row with the same (entity,id)', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.upsertRows('customer', [
        (id: 'c1', payload: '{"v":1}', updatedAt: _ts(1)),
      ]);
      await db.upsertRows('customer', [
        (id: 'c1', payload: '{"v":2}', updatedAt: _ts(3)),
      ]);

      final rows = await db.rowsOf('customer');
      expect(rows, hasLength(1));
      expect(rows.single.payload, '{"v":2}');
      expect(rows.single.updatedAt, _ts(3));
    });

    test('rowsOf isolates by entity', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.upsertRows('customer', [
        (id: 'c1', payload: '{}', updatedAt: _ts(1)),
      ]);
      await db.upsertRows('service_order', [
        (id: 'o1', payload: '{}', updatedAt: _ts(1)),
      ]);

      expect(await db.rowsOf('customer'), hasLength(1));
      expect((await db.rowsOf('service_order')).single.id, 'o1');
    });
  });

  group('Outbox enqueue / pendingFor', () {
    LocalMutation mut(String cmid, String author, {int day = 1}) => LocalMutation(
          clientMutationId: cmid,
          authorUserId: author,
          entity: 'customer',
          op: 'create',
          payload: '{"id":"$cmid"}',
          clientUpdatedAt: _ts(day),
        );

    test('pendingFor returns only this author, ordered by seq', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.enqueue(mut('m1', 'u1'));
      await db.enqueue(mut('m2', 'u2')); // other author, interleaved
      await db.enqueue(mut('m3', 'u1'));
      await db.enqueue(mut('m4', 'u1'));

      final pending = await db.pendingFor('u1');
      expect(pending.map((o) => o.clientMutationId).toList(), ['m1', 'm3', 'm4'],
          reason: 'ordered by seq (insertion order), other authors excluded');
    });

    test('pendingFor excludes non-pending', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.enqueue(mut('m1', 'u1'));
      await db.enqueue(mut('m2', 'u1'));
      await db.markOutbox('m1', 'applied');

      final pending = await db.pendingFor('u1');
      expect(pending.map((o) => o.clientMutationId).toList(), ['m2']);
    });
  });

  group('Outbox markOutbox transitions', () {
    Future<OutboxData> rowOf(LocalDb db, String cmid) =>
        (db.select(db.outbox)..where((t) => t.clientMutationId.equals(cmid)))
            .getSingle();

    test('applied transition', () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.enqueue(LocalMutation(
        clientMutationId: 'm1',
        authorUserId: 'u1',
        entity: 'customer',
        op: 'create',
        payload: '{}',
        clientUpdatedAt: _ts(1),
      ));

      await db.markOutbox('m1', 'applied');

      expect((await rowOf(db, 'm1')).status, 'applied');
    });

    test('failed transition carries a message', () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.enqueue(LocalMutation(
        clientMutationId: 'm1',
        authorUserId: 'u1',
        entity: 'customer',
        op: 'create',
        payload: '{}',
        clientUpdatedAt: _ts(1),
      ));

      await db.markOutbox('m1', 'failed', 'conflito 409');

      final row = await rowOf(db, 'm1');
      expect(row.status, 'failed');
      expect(row.message, 'conflito 409');
    });
  });

  group('Outbox pendingCounts (mine vs others)', () {
    LocalMutation mut(String cmid, String author) => LocalMutation(
          clientMutationId: cmid,
          authorUserId: author,
          entity: 'customer',
          op: 'create',
          payload: '{}',
          clientUpdatedAt: _ts(1),
        );

    test('counts pending split by author, ignoring non-pending', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.enqueue(mut('m1', 'u1'));
      await db.enqueue(mut('m2', 'u1'));
      await db.enqueue(mut('m3', 'u2'));
      await db.markOutbox('m2', 'applied'); // no longer pending

      final counts = await db.pendingCounts('u1');
      expect(counts.mine, 1);
      expect(counts.others, 1);
    });
  });

  group('Outbox failed: badge, retry, descarte e poda (I4)', () {
    Future<OutboxData> rowOf(LocalDb db, String cmid) =>
        (db.select(db.outbox)..where((t) => t.clientMutationId.equals(cmid)))
            .getSingle();

    LocalMutation mut(
      String cmid, {
      String entity = 'customer',
      String op = 'create',
      Map<String, dynamic>? payload,
    }) =>
        LocalMutation(
          clientMutationId: cmid,
          authorUserId: 'u1',
          entity: entity,
          op: op,
          payload: jsonEncode(payload ?? {'id': cmid}),
          clientUpdatedAt: _ts(1),
        );

    test('failedIds separa as falhas das pendentes (unsyncedIds junta as duas)',
        () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.enqueue(mut('m1'));
      await db.enqueue(mut('m2'));
      await db.markOutbox('m2', 'failed', 'Sem permissão.');

      expect(await db.failedIds('customer'), {'m2'});
      expect(await db.unsyncedIds('customer'), {'m1', 'm2'});

      final counts = await db.pendingCounts('u1');
      expect(counts.mine, 1);
      expect(counts.failed, 1);
    });

    test('unsyncedIds enxerga a OS-pai de um item enfileirado (`orderId`)',
        () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.enqueue(mut(
        'm1',
        entity: 'service_order',
        op: 'addItem',
        payload: {'orderId': 'os-1', 'kind': 'service'},
      ));

      expect(await db.unsyncedIds('service_order'), {'os-1'});
    });

    test('retryOutbox re-arma a mutação falha (volta a pending, sem mensagem)',
        () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.enqueue(mut('m1'));
      await db.markOutbox('m1', 'failed', 'Erro do servidor.');

      await db.retryOutbox('m1');

      final row = await rowOf(db, 'm1');
      expect(row.status, 'pending');
      expect(row.message, isNull);
      expect(await db.pendingFor('u1'), hasLength(1));
    });

    test('discardOutbox some com a mutação E com a linha fantasma do create',
        () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.upsertRows('customer', [
        (id: 'm1', payload: '{"id":"m1"}', updatedAt: _ts(1)),
      ]);
      await db.enqueue(mut('m1'));
      await db.markOutbox('m1', 'failed', 'Documento já cadastrado.');

      await db.discardOutbox('m1');

      expect(await db.failedIds('customer'), isEmpty);
      expect(await db.rowsOf('customer'), isEmpty);
    });

    test('discardOutbox de um update NÃO apaga a linha local', () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.upsertRows('customer', [
        (id: 'c1', payload: '{"id":"c1"}', updatedAt: _ts(1)),
      ]);
      await db.enqueue(mut('m1', op: 'update', payload: {'id': 'c1'}));
      await db.markOutbox('m1', 'failed', 'Erro.');

      await db.discardOutbox('m1');

      expect(await db.rowsOf('customer'), hasLength(1));
    });

    test('pruneOutbox remove applied/discarded e preserva pending/failed',
        () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.enqueue(mut('m1'));
      await db.enqueue(mut('m2'));
      await db.enqueue(mut('m3'));
      await db.enqueue(mut('m4'));
      await db.markOutbox('m1', 'applied');
      await db.markOutbox('m2', 'discarded');
      await db.markOutbox('m3', 'failed', 'Erro.');

      expect(await db.pruneOutbox(), 2);

      final left = await db.outboxFor('u1');
      expect(left.map((r) => r.clientMutationId).toSet(), {'m3', 'm4'});
    });
  });

  group('SyncState cursors', () {
    test('saveCursor then cursorFor round-trips ts and id', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.saveCursor('customer', ts: '2026-07-09T00:00:00.000Z', id: 'c9');

      final cur = await db.cursorFor('customer');
      expect(cur, isNotNull);
      expect(cur!.cursorTs, '2026-07-09T00:00:00.000Z');
      expect(cur.cursorId, 'c9');
    });

    test('cursorFor is null when unset', () async {
      final db = _memDb();
      addTearDown(db.close);
      expect(await db.cursorFor('never'), isNull);
    });

    test('saveCursor upserts (second save overwrites)', () async {
      final db = _memDb();
      addTearDown(db.close);

      await db.saveCursor('customer', ts: 'a', id: '1');
      await db.saveCursor('customer', ts: 'b', id: '2');

      final cur = await db.cursorFor('customer');
      expect(cur!.cursorTs, 'b');
      expect(cur.cursorId, '2');
    });
  });

  group('PendingUploads (S6 blobs)', () {
    test('addPendingUpload then listPendingUploads preserves bytes', () async {
      final db = _memDb();
      addTearDown(db.close);
      final bytes = Uint8List.fromList([1, 2, 3, 250, 0, 99]);

      await db.addPendingUpload(
        id: 'up1',
        orderId: 'o1',
        bytes: bytes,
        filename: 'foto.jpg',
        contentType: 'image/jpeg',
        caption: 'antes',
      );

      final ups = await db.listPendingUploads();
      expect(ups, hasLength(1));
      expect(ups.single.bytes, bytes);
      expect(ups.single.filename, 'foto.jpg');
      expect(ups.single.caption, 'antes');
    });

    test('deletePendingUpload removes it', () async {
      final db = _memDb();
      addTearDown(db.close);
      await db.addPendingUpload(
        id: 'up1',
        orderId: 'o1',
        bytes: Uint8List.fromList([1]),
        filename: 'a.jpg',
        contentType: 'image/jpeg',
      );

      await db.deletePendingUpload('up1');

      expect(await db.listPendingUploads(), isEmpty);
    });
  });

  group('forTenant cache + deleteDbForTenant (S5)', () {
    test('forTenant returns the same instance per tenant', () async {
      db_native.executorFactory = (id, file) async => NativeDatabase.memory();

      final a = LocalDb.forTenant('tX');
      final b = LocalDb.forTenant('tX');

      expect(identical(a, b), isTrue);
    });

    test('deleteDbForTenant closes the instance and deletes the file',
        () async {
      final tmp = await Directory.systemTemp.createTemp('orbix_localdb');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      db_native.supportDirOverride = () async => tmp;
      db_native.executorFactory = (id, file) async => NativeDatabase(file);

      final db = LocalDb.forTenant('t1');
      // Force the lazy open (creates the file) by writing a cursor.
      await db.saveCursor('customer', ts: 'x', id: 'y');

      final file = File(p.join(tmp.path, 'orbix_t1.db'));
      expect(await file.exists(), isTrue, reason: 'db file was created');

      await LocalDb.deleteDbForTenant('t1');

      expect(await file.exists(), isFalse, reason: 'S5: replica file removed');
      // Cache cleared: a fresh instance is handed out afterwards.
      db_native.executorFactory = (id, f) async => NativeDatabase.memory();
      expect(identical(LocalDb.forTenant('t1'), db), isFalse);
    });
  });

  group('DbKeyStore', () {
    test('getOrCreate generates 32 random bytes (64 hex) once and reuses',
        () async {
      final storage = _MockSecureStorage();
      final mem = <String, String>{};
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((i) async => mem[i.namedArguments[#key] as String]);
      when(() => storage.write(
                key: any(named: 'key'),
                value: any(named: 'value'),
              ))
          .thenAnswer((i) async {
        final k = i.namedArguments[#key] as String;
        final v = i.namedArguments[#value] as String?;
        if (v == null) {
          mem.remove(k);
        } else {
          mem[k] = v;
        }
      });

      final store = DbKeyStore(storage: storage);
      final k1 = await store.getOrCreate();
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(k1), isTrue,
          reason: '32 bytes hex-encoded');

      final k2 = await store.getOrCreate();
      expect(k2, k1, reason: 'reused, not regenerated');
      verify(() => storage.write(
            key: DbKeyStore.storageKey,
            value: any(named: 'value'),
          )).called(1);
    });
  });
}
