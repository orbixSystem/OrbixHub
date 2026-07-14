import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/error/app_exception.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/core/offline/db/local_db.dart';
import 'package:orbixhub_front/core/offline/sync_api.dart';
import 'package:orbixhub_front/core/offline/sync_engine.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:orbixhub_front/di.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B7 — SyncEngine (push → pull). `LocalDb` real em memória (mesma costura do
/// B5), `SyncApi` fake e o `ConnectivityController` real (com o stream da
/// plataforma sobrescrito). Cobre S1 (autoria), lotes de 100, marcação do
/// outbox, paginação/cursor do pull, ordem push→pull, single-flight, falha de
/// rede no meio e fotos (só depois da OS sincronizar).
LocalDb _memDb() => LocalDb(NativeDatabase.memory());

DateTime _ts(int day) => DateTime.utc(2026, 7, day);

/// Registro de uma chamada de push feita pelo engine.
class _PushCall {
  _PushCall(this.authorUserId, this.mutations);
  final String authorUserId;
  final List<SyncPushMutation> mutations;
}

/// Fake do [SyncApi]: grava as chamadas e devolve páginas/resultados roteirizados.
class _FakeSyncApi implements SyncApi {
  final List<_PushCall> pushes = [];
  final List<String> changesCalls = []; // 'entity@cursorId'
  final List<String> callOrder = []; // 'push' | 'pull'

  /// Páginas roteirizadas por entidade (consumidas em ordem). Entidade sem
  /// roteiro devolve uma página vazia.
  final Map<String, List<SyncChangesPage>> pages = {};

  /// Resposta do push (por chamada). Se vazio, todas as mutações voltam `applied`.
  List<SyncPushOutcome> Function(_PushCall call)? pushResponder;

  /// Se != null, o push da N-ésima chamada (0-based) lança erro de REDE.
  int? failPushAtCall;

  /// Se != null, o push da N-ésima chamada (0-based) lança um erro HTTP do LOTE
  /// com este status (400 = rejeição determinística; 503 = transitório).
  int? httpErrorPushAtCall;
  int httpErrorPushStatus = 400;

  DateTime serverTime = DateTime.utc(2026, 7, 10, 12);

  @override
  Future<SyncPushResult> push({
    required String authorUserId,
    required List<SyncPushMutation> mutations,
  }) async {
    final call = _PushCall(authorUserId, mutations);
    if (failPushAtCall == pushes.length) {
      pushes.add(call);
      callOrder.add('push');
      throw DioException(
        requestOptions: RequestOptions(path: '/sync/push'),
        type: DioExceptionType.connectionError,
      );
    }
    if (httpErrorPushAtCall == pushes.length) {
      pushes.add(call);
      callOrder.add('push');
      throw DioException(
        requestOptions: RequestOptions(path: '/sync/push'),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/sync/push'),
          statusCode: httpErrorPushStatus,
          data: {
            'statusCode': httpErrorPushStatus,
            'error': 'Error',
            'message': httpErrorPushStatus == 400
                ? 'Payload inválido.'
                : 'Serviço indisponível.',
          },
        ),
      );
    }
    pushes.add(call);
    callOrder.add('push');
    final results = pushResponder?.call(call) ??
        [
          for (final m in mutations)
            SyncPushOutcome(
              clientMutationId: m.clientMutationId,
              status: SyncPushStatus.applied,
              entityId: m.payload['id'] as String?,
            ),
        ];
    return SyncPushResult(results: results, serverTime: serverTime);
  }

  @override
  Future<SyncChangesPage> changes({
    required String entity,
    SyncCursor? cursor,
    int limit = 500,
  }) async {
    changesCalls.add('$entity@${cursor?.id ?? '-'}');
    callOrder.add('pull');
    final scripted = pages[entity];
    if (scripted == null || scripted.isEmpty) {
      return SyncChangesPage(
          rows: const [], nextCursor: null, serverTime: serverTime);
    }
    return scripted.removeAt(0);
  }
}

/// Uploads de foto pedidos ao engine (substitui `OsRepository.addPhoto`, que na
/// vida real lança **`AppException`** — nunca `DioException`).
class _PhotoSpy {
  final List<String> uploadedOrderIds = [];

  /// Erro lançado no upload (como o `OsRepositoryImpl` faz: `AppException`).
  Object? error;

  Future<void> call({
    required String orderId,
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? caption,
  }) async {
    uploadedOrderIds.add(orderId);
    final e = error;
    if (e != null) throw e;
  }
}

LocalMutation _mut(
  String cmid, {
  String author = 'u1',
  String entity = 'customer',
  String op = 'create',
  Map<String, dynamic>? payload,
}) =>
    LocalMutation(
      clientMutationId: cmid,
      authorUserId: author,
      entity: entity,
      op: op,
      payload: jsonEncode(payload ?? {'id': cmid, 'nome': 'X'}),
      clientUpdatedAt: _ts(1),
    );

Future<OutboxData> _outboxRow(LocalDb db, String cmid) =>
    (db.select(db.outbox)..where((t) => t.clientMutationId.equals(cmid)))
        .getSingle();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDb db;
  late _FakeSyncApi api;
  late _PhotoSpy photos;
  late ProviderContainer container;
  late ConnectivityController conn;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = _memDb();
    api = _FakeSyncApi();
    photos = _PhotoSpy();
    container = ProviderContainer(overrides: [
      // Nunca toca o platform channel: stream vazio + ping controlado.
      connectivityStreamProvider.overrideWithValue(const Stream.empty()),
      healthPingProvider.overrideWithValue(() async => true),
    ]);
    conn = container.read(connectivityControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  SyncEngine engine({String? userId = 'u1'}) => SyncEngine(
        api: api,
        db: db,
        conn: conn,
        clock: TrustedClock(clock: () => _ts(10)),
        uploadPhoto: photos.call,
        currentUserId: () => userId,
      );

  group('push (S1 — autoria)', () {
    test('envia SÓ as mutações do usuário da sessão atual', () async {
      await db.enqueue(_mut('m1', author: 'u1'));
      await db.enqueue(_mut('m2', author: 'u2')); // outro autor
      await db.enqueue(_mut('m3', author: 'u1'));

      await engine().nudge();

      expect(api.pushes, hasLength(1));
      expect(api.pushes.single.authorUserId, 'u1');
      expect(
        api.pushes.single.mutations.map((m) => m.clientMutationId).toList(),
        ['m1', 'm3'],
      );
      expect((await _outboxRow(db, 'm2')).status, 'pending',
          reason: 'a mutação de outro autor nunca é enviada');
    });

    test('sem sessão (userId null) não faz nada', () async {
      await db.enqueue(_mut('m1'));
      await engine(userId: null).nudge();
      expect(api.pushes, isEmpty);
      expect(api.changesCalls, isEmpty);
    });
  });

  group('push — lotes de 100', () {
    test('150 pendentes → dois lotes (100 + 50)', () async {
      for (var i = 0; i < 150; i++) {
        await db.enqueue(_mut('m$i'));
      }

      await engine().nudge();

      expect(api.pushes, hasLength(2));
      expect(api.pushes[0].mutations, hasLength(100));
      expect(api.pushes[1].mutations, hasLength(50));
    });
  });

  group('push — resultados no outbox', () {
    test('applied / discarded / error(→failed + mensagem)', () async {
      await db.enqueue(_mut('m1'));
      await db.enqueue(_mut('m2'));
      await db.enqueue(_mut('m3'));
      api.pushResponder = (call) => [
            const SyncPushOutcome(
                clientMutationId: 'm1', status: SyncPushStatus.applied),
            const SyncPushOutcome(
                clientMutationId: 'm2', status: SyncPushStatus.discarded),
            const SyncPushOutcome(
              clientMutationId: 'm3',
              status: SyncPushStatus.error,
              message: 'Documento já cadastrado.',
            ),
          ];

      await engine().nudge();

      expect((await _outboxRow(db, 'm1')).status, 'applied');
      expect((await _outboxRow(db, 'm2')).status, 'discarded');
      final failed = await _outboxRow(db, 'm3');
      expect(failed.status, 'failed');
      expect(failed.message, 'Documento já cadastrado.');
    });

    test('um `error` NÃO é reenviado na rodada seguinte', () async {
      await db.enqueue(_mut('m1'));
      api.pushResponder = (call) => [
            const SyncPushOutcome(
              clientMutationId: 'm1',
              status: SyncPushStatus.error,
              message: 'Sem permissão para esta operação.',
            ),
          ];

      final e = engine();
      await e.nudge();
      await e.nudge();

      expect(api.pushes, hasLength(1), reason: 'falha não é retentada');
    });
  });

  group('pull', () {
    test('pagina até nextCursor==null, persiste linhas e salva o cursor',
        () async {
      api.pages['customer'] = [
        SyncChangesPage(
          rows: [
            {'id': 'c1', 'name': 'Ana', 'updated_at': '2026-07-01T00:00:00Z'},
          ],
          nextCursor: const SyncCursor(ts: '2026-07-01T00:00:00.000000Z', id: 'c1'),
          serverTime: api.serverTime,
        ),
        SyncChangesPage(
          rows: [
            {'id': 'c2', 'name': 'Bruno', 'updated_at': '2026-07-02T00:00:00Z'},
          ],
          nextCursor: null,
          serverTime: api.serverTime,
        ),
      ];

      await engine().nudge();

      final rows = await db.rowsOf('customer');
      expect(rows.map((r) => r.id).toSet(), {'c1', 'c2'});
      expect(jsonDecode(rows.firstWhere((r) => r.id == 'c1').payload),
          containsPair('name', 'Ana'));
      final cur = await db.cursorFor('customer');
      expect(cur!.cursorId, 'c1');
      // todas as 11 entidades são puxadas
      expect(api.changesCalls.where((c) => c.startsWith('customer@')).length, 2);
      expect(
        SyncEngine.entities.every(
          (e) => api.changesCalls.any((c) => c.startsWith('$e@')),
        ),
        isTrue,
      );
    });

    test('retoma do cursor salvo na rodada seguinte', () async {
      await db.saveCursor('customer',
          ts: '2026-07-01T00:00:00.000000Z', id: 'c1');

      await engine().nudge();

      expect(api.changesCalls, contains('customer@c1'));
    });
  });

  test('push roda ANTES do pull', () async {
    await db.enqueue(_mut('m1'));

    await engine().nudge();

    expect(api.callOrder.first, 'push');
    expect(api.callOrder.indexOf('pull'), greaterThan(0));
  });

  test('single-flight: dois nudges concorrentes = uma rodada', () async {
    await db.enqueue(_mut('m1'));
    final e = engine();

    await Future.wait([e.nudge(), e.nudge()]);

    expect(api.pushes, hasLength(1));
    expect(api.changesCalls, hasLength(SyncEngine.entities.length),
        reason: 'o pull rodou uma única vez (11 entidades)');
  });

  test('falha de rede no meio do push: fila intacta e estado offline', () async {
    for (var i = 0; i < 150; i++) {
      await db.enqueue(_mut('m$i'));
    }
    api.failPushAtCall = 1; // o 2º lote cai

    await engine().nudge();

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
    // O 1º lote foi aplicado; os 50 restantes seguem pendentes.
    final pending = await db.pendingFor('u1');
    expect(pending, hasLength(50));
    expect(api.changesCalls, isEmpty, reason: 'pull não roda após falha');
  });

  group('erro HTTP do lote no push (não é falha de rede)', () {
    test('400 do lote: mutações viram failed e o PULL continua rodando',
        () async {
      await db.enqueue(_mut('m1'));
      await db.enqueue(_mut('m2'));
      api.httpErrorPushAtCall = 0;

      await engine().nudge();

      final m1 = await _outboxRow(db, 'm1');
      expect(m1.status, 'failed');
      expect(m1.message, 'Payload inválido.');
      expect((await _outboxRow(db, 'm2')).status, 'failed');
      expect(api.changesCalls, hasLength(SyncEngine.entities.length),
          reason: 'o pull (recuperação) roda mesmo com o lote rejeitado');
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.online);
    });

    test('503 (transitório): mutações continuam pending e são reenviadas',
        () async {
      await db.enqueue(_mut('m1'));
      await db.enqueue(_mut('m2'));
      api.httpErrorPushAtCall = 0;
      api.httpErrorPushStatus = 503; // deploy/proxy — NUNCA é terminal

      final e = engine();
      await e.nudge();

      expect((await _outboxRow(db, 'm1')).status, 'pending');
      expect((await _outboxRow(db, 'm2')).status, 'pending');
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
      expect(api.changesCalls, isEmpty, reason: 'rodada abortada, fila intacta');

      // Próxima rodada (servidor de volta): reenvia tudo.
      api.httpErrorPushAtCall = null;
      await e.nudge();
      expect(api.pushes, hasLength(2));
      expect((await _outboxRow(db, 'm1')).status, 'applied');
    });

    test('o lote rejeitado não é reenviado na rodada seguinte', () async {
      await db.enqueue(_mut('m1'));
      api.httpErrorPushAtCall = 0;

      final e = engine();
      await e.nudge();
      await e.nudge();

      expect(api.pushes, hasLength(1));
    });
  });

  test('status desconhecido do servidor mantém a mutação pending', () async {
    await db.enqueue(_mut('m1'));
    api.pushResponder = (call) => [
          const SyncPushOutcome(
              clientMutationId: 'm1', status: SyncPushStatus.unknown),
        ];

    await engine().nudge();

    expect((await _outboxRow(db, 'm1')).status, 'pending',
        reason: 'nunca transformar "não sei" num estado terminal');
  });

  group('fotos pendentes', () {
    Future<void> queuePhoto(String orderId) => db.addPendingUpload(
          id: 'up-$orderId',
          orderId: orderId,
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'f.jpg',
          contentType: 'image/jpeg',
        );

    test('só sobe depois que o create da OS foi aplicado', () async {
      // Create da OS ainda `pending` (é de outro autor — S1 não o empurra nesta
      // sessão): o servidor não conhece a OS, então a foto espera.
      await db.enqueue(_mut('mo',
          author: 'u2', entity: 'service_order', payload: {'id': 'o1'}));
      await queuePhoto('o1');

      await engine().nudge();

      expect(photos.uploadedOrderIds, isEmpty,
          reason: 'a OS não existe no servidor; a foto continua pendente');
      expect(await db.listPendingUploads(), hasLength(1));
    });

    test('sobe e apaga o blob quando a OS sincronizou', () async {
      await db.enqueue(_mut('mo', entity: 'service_order', payload: {'id': 'o1'}));
      await queuePhoto('o1');

      await engine().nudge();

      expect(photos.uploadedOrderIds, ['o1']);
      expect(await db.listPendingUploads(), isEmpty);
    });

    test(
        'erro HTTP no upload (AppException 404): descarta o blob e o pull CONTINUA',
        () async {
      await queuePhoto('o1'); // OS já existente no servidor (sem outbox)
      photos.error = const AppException(
        statusCode: 404,
        error: 'Not Found',
        message: 'OS não encontrada.',
      );

      await engine().nudge();

      expect(await db.listPendingUploads(), isEmpty,
          reason: 'blob terminal descartado — não pode travar a fila');
      expect(api.changesCalls, hasLength(SyncEngine.entities.length),
          reason: 'o pull roda; o device não fica preso na mesma foto');
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.online);
    });

    test('falha de REDE no upload (AppException sem status): fila intacta, offline',
        () async {
      await queuePhoto('o1');
      photos.error = const AppException(
        statusCode: null,
        error: 'Network',
        message: 'Sem conexão com o servidor.',
      );

      await engine().nudge();

      expect(await db.listPendingUploads(), hasLength(1));
      expect(api.changesCalls, isEmpty, reason: 'rodada abortada');
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
    });

    test('500 no upload (transitório): o BLOB é MANTIDO', () async {
      await queuePhoto('o1');
      photos.error = const AppException(
        statusCode: 500,
        error: 'Internal',
        message: 'Erro interno.',
      );

      await engine().nudge();

      expect(await db.listPendingUploads(), hasLength(1),
          reason: 'um 5xx de rotina não pode apagar a foto');
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
    });

    test('create `discarded` (servidor já tem a OS): a foto SOBE', () async {
      await db.enqueue(_mut('mo', entity: 'service_order', payload: {'id': 'o1'}));
      await db.markOutbox('mo', 'discarded');
      await queuePhoto('o1');

      await engine().nudge();

      expect(photos.uploadedOrderIds, ['o1']);
      expect(await db.listPendingUploads(), isEmpty);
    });

    test('blob de OS cujo create falhou de vez é descartado', () async {
      await db.enqueue(_mut('mo', entity: 'service_order', payload: {'id': 'o1'}));
      await db.markOutbox('mo', 'failed', 'Documento inválido.');
      await queuePhoto('o1');

      await engine().nudge();

      expect(photos.uploadedOrderIds, isEmpty);
      expect(await db.listPendingUploads(), isEmpty,
          reason: 'a OS nunca existirá no servidor — o blob não fica preso');
    });
  });

  test('stop() aguarda a rodada em voo (sem use-after-close do LocalDb)',
      () async {
    await db.enqueue(_mut('m1'));
    final e = engine();

    final run = e.nudge();
    await e.stop(); // aguarda a rodada em voo terminar
    await run;
    await e.nudge(); // engine fechado: não inicia nada

    expect(api.pushes, hasLength(1));
  });
}
