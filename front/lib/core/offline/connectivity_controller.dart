import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';

/// Status do indicador global de conectividade/sync.
enum ConnStatus {
  online,
  offline,

  /// Uma sincronização está em andamento (definido pelo SyncEngine via
  /// [ConnectivityController.markSyncing] — nunca inferido só da conectividade).
  syncing,
}

/// Estado imutável de [ConnectivityController]: status atual + contadores de
/// mutações pendentes (outbox deste device vs. mutações de outros autores
/// ainda não puxadas) — atualizados pelo futuro SyncEngine via [ConnectivityController.setPending].
class ConnState {
  const ConnState({
    this.status = ConnStatus.offline,
    this.pendingCount = 0,
    this.pendingOtherAuthors = 0,
    this.failedCount = 0,
  });

  final ConnStatus status;
  final int pendingCount;
  final int pendingOtherAuthors;

  /// Mutações DESTE usuário recusadas pelo servidor (outbox `failed`). Exigem
  /// ação humana (retentar ou descartar) — nunca somem sozinhas.
  final int failedCount;

  ConnState copyWith({
    ConnStatus? status,
    int? pendingCount,
    int? pendingOtherAuthors,
    int? failedCount,
  }) {
    return ConnState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      pendingOtherAuthors: pendingOtherAuthors ?? this.pendingOtherAuthors,
      failedCount: failedCount ?? this.failedCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          pendingCount == other.pendingCount &&
          pendingOtherAuthors == other.pendingOtherAuthors &&
          failedCount == other.failedCount;

  @override
  int get hashCode =>
      Object.hash(status, pendingCount, pendingOtherAuthors, failedCount);

  @override
  String toString() => 'ConnState(status: $status, pendingCount: $pendingCount, '
      'pendingOtherAuthors: $pendingOtherAuthors, failedCount: $failedCount)';
}

/// Stream bruto do `connectivity_plus` — sobrescrito nos testes por um stream
/// controlável (nunca toca um platform channel real em teste).
final connectivityStreamProvider =
    Provider<Stream<List<ConnectivityResult>>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Leitura ÚNICA do estado atual de conectividade, usada no bootstrap.
/// `onConnectivityChanged` só emite MUDANÇAS — sem esta checagem inicial o app
/// nascia `offline` e ficava assim até a rede mudar (na web, provavelmente
/// nunca: o usuário online via o aviso de offline a sessão inteira).
///
/// Se a plataforma não responder (canal ausente em teste, por exemplo),
/// assumimos "tem rede" e deixamos o ping em `/health` dar a palavra final.
final connectivityCheckProvider =
    Provider<Future<List<ConnectivityResult>> Function()>((ref) {
  return () async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return const [ConnectivityResult.wifi];
    }
  };
});

/// Intervalo de re-checagem da API enquanto o SO reporta rede disponível.
/// Sobrescrito nos testes para não esperar 30s de verdade.
final pingIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 30));

/// Caminho pingado (relativo à base do [bareDioProvider]) para confirmar que
/// a API está de fato alcançável — o SO pode reportar "tem rede" com a API
/// fora do ar (backend caído, VPN, portal cativo).
final healthPathProvider = Provider<String>((ref) => '/health');

/// Executa uma checagem de alcançabilidade. Produção: `GET` [healthPathProvider]
/// via [bareDioProvider] (sem interceptors de auth — um ping falho nunca pode
/// disparar refresh de token), `true` só em 2xx. Sobrescrito nos testes por um
/// fake — nenhuma chamada HTTP real acontece nos testes.
final healthPingProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    try {
      final dio = ref.read(bareDioProvider);
      final path = ref.read(healthPathProvider);
      final res = await dio.get<dynamic>(path);
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 300;
    } catch (_) {
      return false;
    }
  };
});

/// Dono do indicador global de conectividade/sync. Combina dois sinais:
/// - o stream do `connectivity_plus` (sem rede ⇒ offline imediatamente, sem
///   necessidade de ping);
/// - um ping periódico em `/health` enquanto o SO reporta rede, porque "tem
///   rede" não significa "API alcançável".
///
/// Também expõe os setters que o (futuro) SyncEngine chama diretamente:
/// [markSyncing], [markSynced], [markOffline], [setPending].
///
/// Semântica de `syncing`:
/// - um ping OK **fresco** nunca derruba `syncing` (a saída normal é do
///   SyncEngine, via [markSynced]/[markOffline]);
/// - um ping FALHO **fresco** (disparado depois do sync começar) demove
///   `syncing` → `offline` — mesma semântica de perder a rede no meio;
/// - pings **stale** (disparados antes da última mudança de conectividade ou
///   do último mark*) são descartados por um contador de geração: cada
///   mudança de conectividade e cada mark* incrementa a geração; o ping
///   captura a geração ao disparar e o resultado só é aplicado se ela não
///   avançou enquanto ele estava em voo. Sem isso, um ping OK lento podia
///   reverter um flap online→offline para `online` sem rede (fail-unsafe),
///   ou um ping pré-sync podia demover `syncing`.
class ConnectivityController extends Notifier<ConnState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;

  /// Geração monotônica: invalida pings em voo quando o mundo muda embaixo
  /// deles (mudança de conectividade ou mark* do SyncEngine).
  int _generation = 0;

  /// O provider já foi descartado (container/teste encerrado): nenhuma
  /// callback assíncrona em voo pode mais tocar o `ref` (isso explodia como
  /// "used after dispose" nos testes que criam e derrubam containers).
  bool _disposed = false;

  @override
  ConnState build() {
    ref.onDispose(_disposeInternal);
    _sub = ref.read(connectivityStreamProvider).listen(
          _onConnectivityChanged,
          // Erro no stream da plataforma: sem sinal confiável ⇒ trate como
          // "sem rede" (fail-safe) em vez de deixar o erro estourar.
          onError: (Object _, StackTrace _) =>
              _onConnectivityChanged(const [ConnectivityResult.none]),
        );
    unawaited(_bootstrap());
    return const ConnState();
  }

  /// Estado inicial: o stream só traz MUDANÇAS, então perguntamos uma vez à
  /// plataforma como está a rede agora e seguimos o fluxo normal (ping em
  /// `/health`). Se uma mudança real chegar antes da resposta, ela vence — o
  /// contador de geração descarta este resultado stale.
  Future<void> _bootstrap() async {
    if (_disposed) return;
    final check = ref.read(connectivityCheckProvider);
    final results = await check();
    if (_disposed) return;
    if (_generation != 0) return; // já houve sinal de verdade: não sobrescreve.
    _onConnectivityChanged(results);
  }

  void _disposeInternal() {
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (_disposed) return;
    _generation++; // invalida qualquer ping em voo da situação anterior
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    _timer?.cancel();
    _timer = null;
    if (!hasNetwork) {
      _applyPingResult(reachable: false);
      return;
    }
    unawaited(_pingHealth());
    _timer = Timer.periodic(ref.read(pingIntervalProvider), (_) {
      unawaited(_pingHealth());
    });
  }

  Future<void> _pingHealth() async {
    if (_disposed) return;
    final generation = _generation;
    final ping = ref.read(healthPingProvider);
    final reachable = await ping();
    if (_disposed) return;
    if (generation != _generation) {
      return; // stale: o estado mudou enquanto o ping estava em voo.
    }
    _applyPingResult(reachable: reachable);
  }

  void _applyPingResult({required bool reachable}) {
    final derived = reachable ? ConnStatus.online : ConnStatus.offline;
    if (derived == ConnStatus.online && state.status == ConnStatus.syncing) {
      return; // syncing só sai por markSynced/markOffline (SyncEngine).
    }
    if (state.status != derived) {
      state = state.copyWith(status: derived);
    }
  }

  /// O SyncEngine iniciou uma rodada de sincronização. Pings em voo
  /// disparados ANTES desta chamada ficam stale (não demovem o syncing).
  void markSyncing() {
    _generation++;
    state = state.copyWith(status: ConnStatus.syncing);
  }

  /// O SyncEngine terminou uma rodada de sincronização com sucesso.
  void markSynced() {
    _generation++;
    state = state.copyWith(status: ConnStatus.online);
  }

  /// O SyncEngine encontrou uma falha de conectividade em andamento.
  void markOffline() {
    _generation++;
    state = state.copyWith(status: ConnStatus.offline);
  }

  /// Atualiza os contadores exibidos pelo indicador: [mine] é o tamanho do
  /// outbox deste device; [others] é o total de mutações de outros autores
  /// ainda não puxadas; [failed] são as mutações deste usuário recusadas pelo
  /// servidor (aparecem em vermelho e pedem retry/descarte).
  void setPending(int mine, int others, [int failed = 0]) {
    state = state.copyWith(
      pendingCount: mine,
      pendingOtherAuthors: others,
      failedCount: failed,
    );
  }
}
