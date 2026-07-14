import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../error/app_exception.dart';
import 'db/local_db.dart';
import 'trusted_clock.dart';

/// Base comum dos repositórios **LocalFirst** (B8) — os decorators que embrulham
/// a impl dio de cada módulo e fazem as telas EXISTENTES funcionarem offline sem
/// mudar uma linha delas.
///
/// Contrato (igual nos 4 módulos):
/// - **Leitura online:** chama a impl real, espelha o resultado no row-store e
///   devolve. O servidor continua sendo a verdade.
/// - **Leitura offline:** monta o mesmo tipo de retorno a partir do row-store
///   (`rowsOf(entity)` → `Model.fromJson`), aplicando filtro/busca/ordenação/
///   paginação em Dart.
/// - **Escrita online:** *write-through* — vai direto na impl real (a tela
///   precisa dos campos que só o servidor calcula: número da OS, totais, saldo
///   do caixa, movimento de estoque) e o resultado é espelhado no row-store.
/// - **Escrita offline:** aplica otimista no row-store e enfileira a mutação no
///   outbox (autoria = usuário da sessão — S1; `clientUpdatedAt` = TrustedClock).
///   O SyncEngine empurra depois; o pull reconcilia.
/// - **Sem op de sync registrada no backend ⇒ não dá para enfileirar:** offline
///   o método lança [AppException] com "Requer conexão" (B9 mostra isso).
abstract class LocalFirstBase {
  LocalFirstBase({
    required this.db,
    required this.clock,
    required this.isOnline,
    required this.currentUserId,
    this.onWrite,
  });

  /// Banco local cifrado do tenant ativo (B5).
  final LocalDb db;

  /// Relógio confiável (S3) — base do `clientUpdatedAt` das mutações.
  final TrustedClock clock;

  /// Caminho de leitura/escrita: `true` → impl real; `false` → row-store/outbox.
  final bool Function() isOnline;

  /// Autoria (S1): dono das mutações enfileiradas. `null` = sem sessão.
  final String? Function() currentUserId;

  /// Chamado depois de CADA escrita local (o `di.dart` liga no
  /// `SyncEngine.nudge()`), para a fila esvaziar assim que houver rede.
  final void Function()? onWrite;

  static const _uuid = Uuid();

  /// Uuid v4 gerado no cliente. Os creates o mandam no payload (`id`) — é assim
  /// que uma linha criada offline mantém a identidade depois do replay.
  String newId() => _uuid.v4();

  // --------------------------- offline-only -----------------------------

  /// Erro padrão dos métodos que **não podem** funcionar offline (não há op de
  /// sync registrada, ou o dado vive só no servidor). Mensagem em PT-BR começando
  /// por "Requer conexão" — a UI (B9) reconhece e trata.
  Never requiresConnection(String acao) => throw AppException(
        statusCode: null,
        error: 'Offline',
        message: 'Requer conexão com a internet para $acao.',
      );

  /// Erro de "não achei localmente" (equivalente offline de um 404).
  Never notFoundLocally(String oQue) => throw AppException(
        statusCode: 404,
        error: 'NotFound',
        message: '$oQue não encontrado(a) nos dados locais.',
      );

  // ---------------------------- row-store -------------------------------

  /// Todas as linhas locais de uma entidade, já desserializadas (JSON cru da API).
  Future<List<Map<String, dynamic>>> rows(String entity) async {
    final list = await db.rowsOf(entity);
    return [
      for (final r in list) jsonDecode(r.payload) as Map<String, dynamic>,
    ];
  }

  /// Uma linha local por id (ou `null`).
  Future<Map<String, dynamic>?> rowById(String entity, String id) async {
    for (final row in await rows(entity)) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  /// Espelha linhas (JSON cru) no row-store — mesma shape do pull.
  Future<void> putRows(String entity, List<Map<String, dynamic>> items) async {
    final mapped = <({String id, String payload, DateTime updatedAt})>[];
    for (final row in items) {
      final id = row['id'];
      if (id is! String) continue;
      mapped.add((id: id, payload: jsonEncode(row), updatedAt: _rowTs(row)));
    }
    await db.upsertRows(entity, mapped);
  }

  Future<void> putRow(String entity, Map<String, dynamic> row) =>
      putRows(entity, [row]);

  /// Remove a linha local (usado nos soft-deletes que somem da listagem e não
  /// têm um `status` para marcar).
  Future<void> removeRow(String entity, String id) async {
    await (db.delete(db.entityRows)
          ..where((t) => t.entity.equals(entity) & t.id.equals(id)))
        .go();
  }

  DateTime _rowTs(Map<String, dynamic> row) {
    for (final key in const ['updated_at', 'created_at']) {
      final v = row[key];
      if (v is String) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed.toUtc();
      }
    }
    return clock.now.toUtc();
  }

  // ------------------------------ outbox --------------------------------

  /// Enfileira uma mutação local (S1: autoria = usuário da sessão) e cutuca o
  /// SyncEngine. `entity.op` DEVE existir na whitelist do backend
  /// (`sync.registry.ts`) — nunca invente uma op.
  Future<void> enqueue(
    String entity,
    String op,
    Map<String, dynamic> payload,
  ) async {
    final userId = currentUserId();
    if (userId == null) {
      throw const AppException(
        statusCode: 401,
        error: 'NoSession',
        message: 'Sessão não encontrada. Entre novamente para continuar.',
      );
    }
    await db.enqueue(
      LocalMutation(
        clientMutationId: newId(),
        authorUserId: userId,
        entity: entity,
        op: op,
        payload: jsonEncode(payload),
        clientUpdatedAt: clock.now.toUtc(),
      ),
    );
    onWrite?.call();
  }

  // ------------------------------ util ----------------------------------

  String nowIso() => clock.now.toUtc().toIso8601String();

  /// Decimais viajam como String nos modelos (espelho do `numeric` do Postgres).
  String? dec(num? v) => v?.toStringAsFixed(2);

  /// Paginação em memória (mesma régua do backend: página 1-based).
  List<T> pageOf<T>(List<T> items, int page, int pageSize) {
    final start = (page - 1) * pageSize;
    if (start >= items.length || start < 0) return const [];
    final end = start + pageSize;
    return items.sublist(start, end > items.length ? items.length : end);
  }

  /// Comparação de busca (case-insensitive, "contém").
  bool matches(String? haystack, String needle) =>
      haystack != null && haystack.toLowerCase().contains(needle.toLowerCase());

  num toNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }
}

/// Chave (pseudo-entidade) do row-store onde as `config` dos módulos são
/// espelhadas. Não são entidades de pull — o cache é gravado no caminho ONLINE
/// (`fetchConfig`) e lido offline; o `_` no prefixo evita colisão com as 11
/// entidades replicadas.
class LocalConfigEntities {
  static const customers = '_config_customers';
  static const inventory = '_config_inventory';
  static const cashier = '_config_cashier';

  /// Id fixo da linha única de config.
  static const rowId = 'config';
}
