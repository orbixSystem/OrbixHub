import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../error/app_exception.dart';
import 'connectivity_controller.dart';
import 'db/local_db.dart';
import 'sync_api.dart';
import 'trusted_clock.dart';

/// Sobe UMA foto pendente. Ligado a `OsRepository.addPhoto` no `di.dart` — o
/// engine não conhece o módulo OS (só este callback estreito).
typedef PhotoUploader = Future<void> Function({
  required String orderId,
  required List<int> bytes,
  required String filename,
  required String contentType,
  String? caption,
});

/// Motor de sincronização offline-first (B7).
///
/// **Ordem: push → fotos → pull.** Push primeiro para que o servidor conheça as
/// entidades criadas offline antes de devolvê-las no pull (e para que as fotos
/// tenham uma OS de destino). O pull vem por último e é a reconciliação final —
/// o servidor é a fonte de verdade (uma mutação `discarded`/`error` é corrigida
/// pela linha que volta no pull).
///
/// Invariantes:
/// - **S1 (autoria)**: só empurra mutações cujo `authorUserId` é o usuário da
///   sessão atual. O servidor rejeita o lote inteiro (403) se a autoria não
///   casar com o `sub` do JWT — mutações de outro usuário do mesmo device ficam
///   `pending` até ELE logar.
/// - **Single-flight**: nunca há duas rodadas ao mesmo tempo. Um [nudge] durante
///   uma rodada marca "sujo" e reexecuta UMA vez ao final — e só se houver
///   trabalho de outbox novo (o pull acabou de rodar).
/// - **`error` não é retentado**: o outbox vira `failed` com a mensagem PT-BR e
///   fica lá para a UI mostrar; a linha correta chega pelo pull.
/// - **Web**: inerte (`kIsWeb` → não há banco local; a web é online-only).
class SyncEngine {
  SyncEngine({
    required this.api,
    required this.db,
    required this.conn,
    required this.clock,
    required this.uploadPhoto,
    required this.currentUserId,
    this.interval = const Duration(seconds: 60),
    this.maxPagesPerEntity = 200,
  });

  /// As 11 entidades replicadas (espelha `PULL_ROUTES` do backend).
  static const entities = <String>[
    'customer',
    'subject',
    'inventory_item',
    'stock_movement',
    'service_order',
    'service_order_item',
    'service_order_event',
    'service_order_photo',
    'service_order_template',
    'cash_session',
    'cash_entry',
  ];

  final SyncApi api;
  final LocalDb db;
  final ConnectivityController conn;
  final TrustedClock clock;
  final PhotoUploader uploadPhoto;

  /// Id do usuário da sessão atual (`null` = sem sessão) — a autoria de S1.
  final String? Function() currentUserId;

  /// Período do disparo automático enquanto o app está de pé.
  final Duration interval;

  /// Teto de páginas por entidade numa rodada (anti-loop de servidor patológico).
  final int maxPagesPerEntity;

  Timer? _timer;
  Future<void>? _running;
  bool _dirty = false;
  bool _closed = false;

  /// Liga o motor: dispara uma rodada agora e depois a cada [interval]. Idempotente.
  void start() {
    if (kIsWeb) return;
    _timer ??= Timer.periodic(interval, (_) => unawaited(nudge()));
    unawaited(nudge());
  }

  /// Desliga o motor (logout / troca de tenant / dispose do provider): cancela o
  /// timer, impede novas rodadas e **aguarda a rodada em voo terminar**. Quem for
  /// fechar o `LocalDb` (logout/troca de tenant) DEVE aguardar este Future —
  /// fechar o banco no meio de uma rodada seria use-after-close.
  Future<void> stop() async {
    _closed = true;
    _timer?.cancel();
    _timer = null;
    await _running;
  }

  /// Pede uma sincronização. Chamado pelos repositórios LocalFirst (B8) depois
  /// de CADA escrita local, ao voltar a ficar online e pelo timer de 60s.
  ///
  /// Single-flight: se já há uma rodada em voo, devolve o Future DELA (marcando
  /// "sujo" para uma reexecução do outbox ao final) — nunca inicia uma segunda.
  Future<void> nudge() {
    if (_closed) return Future.value();
    final inFlight = _running;
    if (inFlight != null) {
      _dirty = true;
      return inFlight;
    }
    final run = _loop();
    _running = run;
    return run;
  }

  Future<void> _loop() async {
    try {
      await _runOnce();
      // Reexecuta só se algo entrou na fila durante a rodada (o pull já rodou).
      while (_dirty && !_closed) {
        _dirty = false;
        final hasWork = await _hasOutboxWork();
        // Um nudge que chegou DURANTE a consulta acima não pode ser perdido:
        // a resposta é stale. Volta a marcar sujo e reavalia no próximo giro.
        if (!hasWork) {
          if (_dirty) continue;
          break;
        }
        await _runOnce();
      }
    } finally {
      _running = null;
      // NÃO zera `_dirty` aqui: um nudge que chegou depois da última avaliação
      // (mas antes de soltarmos o single-flight) seria perdido — a escrita local
      // esperaria até 60s pelo timer.
    }
  }

  Future<bool> _hasOutboxWork() async {
    final userId = currentUserId();
    if (userId == null) return false;
    final pending = await db.pendingFor(userId);
    if (pending.isNotEmpty) return true;
    return (await db.listPendingUploads()).isNotEmpty;
  }

  /// UMA rodada completa. Falha de rede em qualquer ponto: para, deixa a fila
  /// intacta e volta o indicador para `offline`.
  Future<void> _runOnce() async {
    if (kIsWeb || _closed) return;
    final userId = currentUserId();
    if (userId == null) return; // sem sessão: nada a sincronizar.

    conn.markSyncing();
    try {
      await _push(userId);
      await _uploadPendingPhotos();
      await _pull();
      conn.markSynced();
    } catch (_) {
      // Rede fora (ou erro inesperado): fila preservada, indicador offline.
      conn.markOffline();
    } finally {
      await _publishPendingCounts(userId);
    }
  }

  Future<void> _publishPendingCounts(String userId) async {
    // Best-effort: se o banco foi fechado por baixo (logout/troca de tenant no
    // meio da rodada), publicar contadores não pode virar erro não tratado.
    try {
      final counts = await db.pendingCounts(userId);
      conn.setPending(counts.mine, counts.others);
    } catch (_) {
      // ignora — o indicador é atualizado na próxima rodada.
    }
  }

  // ----------------------------- push ----------------------------------

  Future<void> _push(String userId) async {
    final pending = await db.pendingFor(userId); // S1 + ordem por seq
    for (var i = 0; i < pending.length; i += SyncApiLimits.pushBatchSize) {
      final batch = pending.sublist(
        i,
        math.min(i + SyncApiLimits.pushBatchSize, pending.length),
      );
      final SyncPushResult res;
      try {
        res = await api.push(
          authorUserId: userId,
          mutations: [for (final row in batch) _toMutation(row)],
        );
      } catch (e) {
        final http = _httpFailure(e);
        if (http == null) rethrow; // rede fora: aborta a rodada, fila intacta.
        // Erro HTTP do LOTE INTEIRO (400 de uma mutação malformada, 403 de
        // autoria): retentar produziria o MESMO erro para sempre e travaria o
        // pull. Marca o lote como `failed` (com a mensagem do servidor) e segue
        // — a reconciliação correta vem do pull, que é a fonte de verdade.
        for (final row in batch) {
          await db.markOutbox(row.clientMutationId, 'failed', http);
        }
        continue;
      }
      await _observe(res.serverTime);
      for (final r in res.results) {
        final status = r.status.outboxStatus;
        // Status desconhecido (servidor novo/resposta truncada) fica `pending`:
        // nunca transforme "não sei" num estado terminal.
        if (status == null) continue;
        // `error` → `failed` (com a mensagem PT-BR) e NUNCA volta a `pending`:
        // a linha correta chega pelo pull; retentar cegamente repetiria a falha.
        await db.markOutbox(r.clientMutationId, status, r.message);
      }
    }
  }

  /// Mensagem do erro se ele for uma FALHA HTTP (o servidor respondeu); `null`
  /// se for falha de rede (ou qualquer outra coisa) — que aborta a rodada.
  ///
  /// Cobre os dois formatos que chegam aqui: `DioException` cru (do [SyncApi],
  /// deliberadamente fino) e `AppException` (os repositórios de feature — como o
  /// `OsRepositoryImpl` do upload de fotos — mapeiam todo erro dio para ela).
  String? _httpFailure(Object e) {
    if (e is AppException) {
      return e.isNetwork ? null : e.message;
    }
    if (e is DioException) {
      if (e.response == null) return null;
      return AppException.fromDio(e).message;
    }
    return null;
  }

  SyncPushMutation _toMutation(OutboxData row) => SyncPushMutation(
        clientMutationId: row.clientMutationId,
        entity: row.entity,
        op: row.op,
        payload: jsonDecode(row.payload) as Map<String, dynamic>,
        clientUpdatedAt: row.clientUpdatedAt,
      );

  // ----------------------------- fotos ----------------------------------

  /// Sobe os anexos pendentes (BLOBs, S6) — mas SÓ os de OS que já existem no
  /// servidor. Uma OS criada offline cujo `create` ainda está `pending` (ou
  /// falhou) não tem destino: a foto continua na fila.
  Future<void> _uploadPendingPhotos() async {
    final uploads = await db.listPendingUploads();
    if (uploads.isEmpty) return;
    final unsynced = await _orderIdsByCreateStatus(pendingOnly: true);

    final doomed = await _orderIdsByCreateStatus(pendingOnly: false);

    for (final up in uploads) {
      // OS cujo create MORREU no servidor (failed/discarded): a OS nunca vai
      // existir — o blob ficaria preso na fila para sempre. Descarta.
      if (doomed.contains(up.orderId)) {
        await db.deletePendingUpload(up.id);
        continue;
      }
      // OS ainda não empurrada: a foto espera a próxima rodada.
      if (unsynced.contains(up.orderId)) continue;
      try {
        await uploadPhoto(
          orderId: up.orderId,
          bytes: up.bytes,
          filename: up.filename,
          contentType: up.contentType,
          caption: up.caption,
        );
        await db.deletePendingUpload(up.id);
      } catch (e) {
        // O uploader é o `OsRepository.addPhoto` REAL, que mapeia todo erro dio
        // para `AppException` — por isso a checagem é por `_httpFailure`, não
        // por `DioException`.
        if (_httpFailure(e) == null) rethrow; // rede fora: aborta a rodada.
        // Erro HTTP terminal (404 OS apagada, 413 grande demais, 415 formato):
        // descarta o blob — insistir prenderia a fila (e o pull) para sempre.
        await db.deletePendingUpload(up.id);
      }
    }
  }

  /// Ids de OS cujo `create` local ainda NÃO foi aplicado pelo servidor —
  /// [pendingOnly] `true`: só as que ainda estão na fila (`pending`, podem
  /// chegar lá); `false`: as terminais (`failed`/`discarded`, nunca chegarão).
  Future<Set<String>> _orderIdsByCreateStatus({required bool pendingOnly}) async {
    final rows = await (db.select(db.outbox)
          ..where((t) {
            final create =
                t.entity.equals('service_order') & t.op.equals('create');
            return pendingOnly
                ? create & t.status.equals('pending')
                : create &
                    (t.status.equals('failed') | t.status.equals('discarded'));
          }))
        .get();
    final ids = <String>{};
    for (final r in rows) {
      final id = (jsonDecode(r.payload) as Map<String, dynamic>)['id'];
      if (id is String) ids.add(id);
    }
    return ids;
  }

  // ----------------------------- pull -----------------------------------

  Future<void> _pull() async {
    for (final entity in entities) {
      await _pullEntity(entity);
    }
  }

  Future<void> _pullEntity(String entity) async {
    final saved = await db.cursorFor(entity);
    var cursor = (saved?.cursorTs != null && saved?.cursorId != null)
        ? SyncCursor(ts: saved!.cursorTs!, id: saved.cursorId!)
        : null;

    // Loop limitado: um servidor patológico (nextCursor que nunca acaba) não
    // pode prender a rodada para sempre.
    for (var page = 0; page < maxPagesPerEntity; page++) {
      final SyncChangesPage res;
      try {
        res = await api.changes(entity: entity, cursor: cursor);
      } catch (e) {
        if (_httpFailure(e) == null) rethrow; // rede fora: aborta a rodada.
        // 403 (cargo sem permissão de leitura desta entidade) / 400: essa
        // entidade simplesmente não é replicada para este usuário.
        return;
      }
      await _persist(entity, res.rows);
      await _observe(res.serverTime);
      final next = res.nextCursor;
      if (next == null) return; // fim das mudanças desta entidade.
      // O cursor só avança com `nextCursor` do servidor (texto com precisão de
      // microssegundo). A última página parcial é re-lida na próxima rodada —
      // o upsert é idempotente, e isso evita perder linhas do mesmo instante.
      await db.saveCursor(entity, ts: next.ts, id: next.id);
      cursor = next;
    }
  }

  Future<void> _persist(String entity, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final mapped = <({String id, String payload, DateTime updatedAt})>[];
    for (final row in rows) {
      final id = row['id'];
      if (id is! String) continue; // linha sem id: não é endereçável.
      mapped.add((
        id: id,
        payload: jsonEncode(row),
        updatedAt: _rowTs(row),
      ));
    }
    await db.upsertRows(entity, mapped);
  }

  /// Timestamp da linha: `updated_at` quando existe; senão `created_at` (as
  /// entidades append-only — movimento de estoque, evento/foto de OS — só têm
  /// esse). Sem nenhum dos dois, cai no relógio local.
  DateTime _rowTs(Map<String, dynamic> row) {
    for (final key in const ['updated_at', 'updatedAt', 'created_at', 'createdAt']) {
      final v = row[key];
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed.toUtc();
      }
    }
    return clock.now.toUtc();
  }

  /// S3 — todo `serverTime` visto alimenta o relógio confiável (anti-rollback).
  Future<void> _observe(DateTime? serverTime) async {
    if (serverTime == null) return;
    await clock.observe(serverTime);
  }
}
