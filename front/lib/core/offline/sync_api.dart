import 'package:dio/dio.dart';

/// Cliente fino dos dois endpoints do sync offline-first
/// (`GET /sync/changes`, `POST /sync/push`) + os tipos do contrato.
///
/// É deliberadamente "burro": não mapeia erro para `AppException` (o SyncEngine
/// precisa distinguir falha de REDE — fila intacta, volta a offline — de erro
/// HTTP de negócio, que é por-entidade/por-mutação), não conhece o outbox e não
/// conhece domínio: as linhas do pull são devolvidas como o JSON cru da API
/// (os repositórios LocalFirst do B8 é que as desserializam).

/// Cursor opaco `(ts,id)` devolvido pelo pull — `ts` é texto ISO com precisão de
/// microssegundo (gerado pelo Postgres), NUNCA um `DateTime` (perderia a fração
/// e faria a última linha reaparecer).
class SyncCursor {
  const SyncCursor({required this.ts, required this.id});

  final String ts;
  final String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncCursor && ts == other.ts && id == other.id;

  @override
  int get hashCode => Object.hash(ts, id);

  @override
  String toString() => 'SyncCursor($ts, $id)';
}

/// Uma página de `GET /sync/changes`.
///
/// [nextCursor] vem em TODA página não vazia (inclusive a última, parcial) — o
/// cliente SEMPRE o persiste, senão a rodada seguinte rebaixaria a tabela
/// inteira de novo. Quem diz "ainda há mais" é [hasMore] (a página encheu o
/// limite), não o cursor.
class SyncChangesPage {
  const SyncChangesPage({
    required this.rows,
    required this.nextCursor,
    required this.serverTime,
    this.hasMore = false,
  });

  /// Linhas cruas da API (mesmo shape dos endpoints de leitura do módulo dono).
  final List<Map<String, dynamic>> rows;
  final SyncCursor? nextCursor;
  final DateTime? serverTime;

  /// A página encheu o limite: pode haver mais mudanças depois do cursor.
  final bool hasMore;
}

/// Uma mutação do outbox pronta para o `POST /sync/push`.
class SyncPushMutation {
  const SyncPushMutation({
    required this.clientMutationId,
    required this.entity,
    required this.op,
    required this.payload,
    required this.clientUpdatedAt,
  });

  final String clientMutationId;
  final String entity;
  final String op;
  final Map<String, dynamic> payload;
  final DateTime clientUpdatedAt;

  Map<String, dynamic> toJson() => {
        'clientMutationId': clientMutationId,
        'entity': entity,
        'op': op,
        'payload': payload,
        'clientUpdatedAt': clientUpdatedAt.toUtc().toIso8601String(),
      };
}

/// Desfecho de UMA mutação no servidor.
/// - `applied`: aplicada;
/// - `discarded`: perdeu o last-write-wins (a linha do servidor era mais nova);
/// - `error`: validação/permissão/conflito — mensagem em PT-BR, NÃO se retenta;
/// - `unknown`: status que este cliente não conhece (servidor mais novo,
///   resposta truncada). NUNCA vira estado terminal — a mutação fica `pending`
///   (marcar `failed` poderia exibir como falha algo que o servidor aplicou).
enum SyncPushStatus {
  applied,
  discarded,
  error,
  unknown;

  static SyncPushStatus fromWire(String? s) => switch (s) {
        'applied' => SyncPushStatus.applied,
        'discarded' => SyncPushStatus.discarded,
        'error' => SyncPushStatus.error,
        _ => SyncPushStatus.unknown,
      };

  /// Status correspondente na coluna `status` do outbox local — `null` quando
  /// não há transição a fazer (`unknown`: continua `pending`).
  String? get outboxStatus => switch (this) {
        SyncPushStatus.applied => 'applied',
        SyncPushStatus.discarded => 'discarded',
        SyncPushStatus.error => 'failed',
        SyncPushStatus.unknown => null,
      };
}

class SyncPushOutcome {
  const SyncPushOutcome({
    required this.clientMutationId,
    required this.status,
    this.entityId,
    this.message,
  });

  final String clientMutationId;
  final SyncPushStatus status;

  /// Id da entidade no servidor (útil quando ele gera o id — ex.: item de OS).
  final String? entityId;

  /// Motivo (PT-BR) quando `status == error`.
  final String? message;

  static SyncPushOutcome fromJson(Map<String, dynamic> j) => SyncPushOutcome(
        clientMutationId: j['clientMutationId'] as String,
        status: SyncPushStatus.fromWire(j['status'] as String?),
        entityId: j['entityId'] as String?,
        message: j['message'] as String?,
      );
}

class SyncPushResult {
  const SyncPushResult({required this.results, required this.serverTime});

  final List<SyncPushOutcome> results;
  final DateTime? serverTime;
}

/// Contrato do cliente de sync (fakeado nos testes do engine).
abstract class SyncApi {
  /// Pull incremental de uma entidade a partir de [cursor] (null = do início).
  Future<SyncChangesPage> changes({
    required String entity,
    SyncCursor? cursor,
    int limit,
  });

  /// Push idempotente de um lote (≤100 — S10) de mutações do MESMO autor (S1).
  Future<SyncPushResult> push({
    required String authorUserId,
    required List<SyncPushMutation> mutations,
  });
}

/// Implementação real sobre o dio autenticado (bearer + refresh single-flight).
class DioSyncApi implements SyncApi {
  const DioSyncApi(this._dio);

  final Dio _dio;

  @override
  Future<SyncChangesPage> changes({
    required String entity,
    SyncCursor? cursor,
    int limit = SyncApiLimits.pullPageSize,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/sync/changes',
      queryParameters: {
        'entity': entity,
        'limit': limit,
        if (cursor != null) 'sinceTs': cursor.ts,
        if (cursor != null) 'sinceId': cursor.id,
      },
    );
    final data = res.data ?? const <String, dynamic>{};
    final rows = (data['rows'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final next = data['nextCursor'] as Map<String, dynamic>?;
    return SyncChangesPage(
      rows: rows,
      nextCursor: next == null
          ? null
          : SyncCursor(ts: next['ts'] as String, id: next['id'] as String),
      serverTime: DateTime.tryParse(data['serverTime'] as String? ?? ''),
      hasMore: data['hasMore'] == true,
    );
  }

  @override
  Future<SyncPushResult> push({
    required String authorUserId,
    required List<SyncPushMutation> mutations,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/sync/push',
      data: {
        'authorUserId': authorUserId,
        'mutations': [for (final m in mutations) m.toJson()],
      },
    );
    final data = res.data ?? const <String, dynamic>{};
    final results = (data['results'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SyncPushOutcome.fromJson)
        .toList(growable: false);
    return SyncPushResult(
      results: results,
      serverTime: DateTime.tryParse(data['serverTime'] as String? ?? ''),
    );
  }
}

/// Limites do contrato (espelham o backend — S10, anti-DoS).
abstract final class SyncApiLimits {
  /// Máximo de mutações por `POST /sync/push` (o servidor rejeita acima disso).
  static const pushBatchSize = 100;

  /// Página do pull (o servidor clampa em 500).
  static const pullPageSize = 500;
}
