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
  });

  final ConnStatus status;
  final int pendingCount;
  final int pendingOtherAuthors;

  ConnState copyWith({
    ConnStatus? status,
    int? pendingCount,
    int? pendingOtherAuthors,
  }) {
    return ConnState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      pendingOtherAuthors: pendingOtherAuthors ?? this.pendingOtherAuthors,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          pendingCount == other.pendingCount &&
          pendingOtherAuthors == other.pendingOtherAuthors;

  @override
  int get hashCode => Object.hash(status, pendingCount, pendingOtherAuthors);

  @override
  String toString() => 'ConnState(status: $status, pendingCount: $pendingCount, '
      'pendingOtherAuthors: $pendingOtherAuthors)';
}

/// Stream bruto do `connectivity_plus` — sobrescrito nos testes por um stream
/// controlável (nunca toca um platform channel real em teste).
final connectivityStreamProvider =
    Provider<Stream<List<ConnectivityResult>>>((ref) {
  return Connectivity().onConnectivityChanged;
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
/// [markSyncing], [markSynced], [markOffline], [setPending]. Um ping
/// bem-sucedido NUNCA derruba um `syncing` em andamento — só perder
/// conectividade (sem rede, ou o próprio ping falhando) o faz; a saída normal
/// de `syncing` é responsabilidade do SyncEngine.
class ConnectivityController extends Notifier<ConnState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _timer;

  @override
  ConnState build() {
    ref.onDispose(_disposeInternal);
    _sub = ref.read(connectivityStreamProvider).listen(_onConnectivityChanged);
    return const ConnState();
  }

  void _disposeInternal() {
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
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
    final ping = ref.read(healthPingProvider);
    final reachable = await ping();
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

  /// O SyncEngine iniciou uma rodada de sincronização.
  void markSyncing() => state = state.copyWith(status: ConnStatus.syncing);

  /// O SyncEngine terminou uma rodada de sincronização com sucesso.
  void markSynced() => state = state.copyWith(status: ConnStatus.online);

  /// O SyncEngine encontrou uma falha de conectividade em andamento.
  void markOffline() => state = state.copyWith(status: ConnStatus.offline);

  /// Atualiza os contadores exibidos pelo indicador: [mine] é o tamanho do
  /// outbox deste device; [others] é o total de mutações de outros autores
  /// ainda não puxadas.
  void setPending(int mine, int others) {
    state = state.copyWith(pendingCount: mine, pendingOtherAuthors: others);
  }
}
