import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/di.dart';

/// Controllable stand-in for `connectivity_plus`'s stream + a fake `/health`
/// ping — no platform channel and no real HTTP call in these tests.
///
/// [gate], when set, holds the NEXT ping in flight until the test completes
/// it (one-shot) — used to simulate a slow ping racing newer events.
class _FakePing {
  bool result = true;
  int callCount = 0;
  Completer<bool>? gate;

  Future<bool> call() async {
    callCount++;
    final g = gate;
    if (g != null) {
      gate = null;
      return g.future;
    }
    return result;
  }
}

void main() {
  late StreamController<List<ConnectivityResult>> connectivity;
  late _FakePing ping;

  /// Resposta do `checkConnectivity()` do bootstrap. Por padrão NUNCA
  /// completa: os testes de stream abaixo exercitam só o caminho dos eventos,
  /// como antes. Os testes de bootstrap completam este future.
  late Completer<List<ConnectivityResult>> initialCheck;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(overrides: [
      connectivityStreamProvider.overrideWithValue(connectivity.stream),
      healthPingProvider.overrideWithValue(ping.call),
      connectivityCheckProvider.overrideWithValue(() => initialCheck.future),
    ]);
    addTearDown(c.dispose);
    // Notifiers are lazy: force `build()` (and therefore the stream
    // subscription) now, BEFORE any test pushes events into the broadcast
    // `connectivity` controller — broadcast streams never replay, so an
    // event pushed before a listener exists is silently lost.
    c.read(connectivityControllerProvider);
    return c;
  }

  setUp(() {
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivity.close);
    ping = _FakePing();
    initialCheck = Completer<List<ConnectivityResult>>();
  });

  test('starts offline before any connectivity signal arrives', () {
    final container = makeContainer();
    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
  });

  group('bootstrap (checkConnectivity inicial)', () {
    // O stream do connectivity_plus só emite MUDANÇAS: sem esta checagem
    // inicial o app nascia offline e ficava assim (na web, a sessão inteira).
    test('rede disponível no boot + ping ok ⇒ online, sem nenhum evento de '
        'stream', () async {
      final container = makeContainer();
      initialCheck.complete([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.online);
      expect(ping.callCount, greaterThanOrEqualTo(1));
    });

    test('sem rede no boot ⇒ offline (e nem pinga)', () async {
      final container = makeContainer();
      initialCheck.complete([ConnectivityResult.none]);
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
      expect(ping.callCount, 0);
    });

    test('um evento REAL do stream durante o boot vence a checagem inicial '
        '(resultado stale é descartado)', () async {
      final container = makeContainer();
      connectivity.add([ConnectivityResult.none]); // queda real, antes do check
      await pumpEventQueue();
      initialCheck.complete([ConnectivityResult.wifi]); // stale
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
      expect(ping.callCount, 0);
    });
  });

  test('no network reported ⇒ offline immediately, without pinging', () async {
    final container = makeContainer();
    connectivity.add([ConnectivityResult.none]);
    await pumpEventQueue();

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
    expect(ping.callCount, 0, reason: 'no network ⇒ pinging is pointless');
  });

  test('network up + ping ok ⇒ online', () async {
    final container = makeContainer();
    ping.result = true;
    connectivity.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.online);
    expect(ping.callCount, greaterThanOrEqualTo(1));
  });

  test('network up but /health unreachable ⇒ stays offline', () async {
    final container = makeContainer();
    ping.result = false;
    connectivity.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
    expect(ping.callCount, greaterThanOrEqualTo(1),
        reason: 'the ping must actually run — offline here for the right reason');
  });

  test('losing the network after being online ⇒ offline again', () async {
    final container = makeContainer();
    ping.result = true;
    connectivity.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.online);

    connectivity.add([ConnectivityResult.none]);
    await pumpEventQueue();

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
  });

  test('pings again periodically while the network stays up', () {
    // fakeAsync: the 30s periodic timer is driven by a fake clock —
    // deterministic, no wall-clock sleeps (anti-flake).
    fakeAsync((fake) {
      final container = makeContainer();
      ping.result = true;
      connectivity.add([ConnectivityResult.wifi]);
      fake.flushMicrotasks();
      expect(ping.callCount, 1, reason: 'immediate ping on network up');

      fake.elapse(const Duration(seconds: 95)); // 3 periodic ticks of 30s

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.online);
      expect(ping.callCount, 4,
          reason: 'the 30s periodic ping must keep firing (1 imediato + 3 ticks)');
    });
  });

  group('SyncEngine setters', () {
    test('markSyncing sets syncing regardless of connectivity', () {
      final container = makeContainer();
      container.read(connectivityControllerProvider.notifier).markSyncing();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.syncing);
    });

    test('a successful ping never downgrades an in-progress syncing state',
        () async {
      final container = makeContainer();
      container.read(connectivityControllerProvider.notifier).markSyncing();
      ping.result = true;

      connectivity.add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.syncing,
          reason: 'only the SyncEngine (markSynced/markOffline) exits syncing');
    });

    test('losing connectivity DOES override syncing back to offline',
        () async {
      final container = makeContainer();
      container.read(connectivityControllerProvider.notifier).markSyncing();

      connectivity.add([ConnectivityResult.none]);
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
    });

    test('markSynced transitions syncing → online', () {
      final container = makeContainer();
      final notifier = container.read(connectivityControllerProvider.notifier);
      notifier.markSyncing();

      notifier.markSynced();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.online);
    });

    test(
        'regressão: sem rede (SO reporta none), markSyncing/markSynced NÃO '
        'voltam a online — o backend local alcançável com WiFi off não conta',
        () async {
      final container = makeContainer();
      final notifier = container.read(connectivityControllerProvider.notifier);
      // WiFi desligado: o SO reporta sem rede → offline.
      connectivity.add([ConnectivityResult.none]);
      await pumpEventQueue();
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);

      // O SyncEngine sincroniza com o localhost (alcançável) e tenta marcar
      // syncing/online — mas sem interface de rede isso é no-op.
      notifier.markSyncing();
      notifier.markSynced();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline,
          reason: 'sem internet real, alcançar um backend local não pode '
              'reivindicar online (NF/APIs externas dependem de rede)');
    });

    test('markOffline forces offline', () {
      final container = makeContainer();
      final notifier = container.read(connectivityControllerProvider.notifier);
      notifier.markSyncing();

      notifier.markOffline();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);
    });

    test('setPending updates the counters without touching status', () {
      final container = makeContainer();
      final notifier = container.read(connectivityControllerProvider.notifier);

      notifier.setPending(3, 7);

      final state = container.read(connectivityControllerProvider);
      expect(state.pendingCount, 3);
      expect(state.pendingOtherAuthors, 7);
      expect(state.status, ConnStatus.offline);
    });
  });

  test('online → API stops responding → next periodic ping demotes to offline',
      () {
    fakeAsync((fake) {
      final container = makeContainer();
      ping.result = true;
      connectivity.add([ConnectivityResult.wifi]);
      fake.flushMicrotasks();
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.online);

      ping.result = false; // backend caiu; o SO ainda reporta rede
      fake.elapse(const Duration(seconds: 30)); // próximo tick periódico

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline,
          reason: 'rede sem API alcançável = offline, mesmo depois de online');
    });
  });

  group('stale-ping race (generation guard)', () {
    test(
        'flap regression: a stale OK ping resolving after network loss '
        'cannot flip the state back to online', () async {
      final container = makeContainer();
      final gate = Completer<bool>();
      ping.gate = gate;

      connectivity.add([ConnectivityResult.wifi]); // fires ping, held in flight
      await pumpEventQueue();
      connectivity.add([ConnectivityResult.none]); // offline immediately
      await pumpEventQueue();
      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline);

      gate.complete(true); // the stale pre-flap ping finally resolves OK
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.offline,
          reason: 'a stale ping from before the flap must be dropped — '
              'claiming online with no network is fail-unsafe');
    });

    test('a stale FAILED ping (fired before markSyncing) never demotes syncing',
        () async {
      final container = makeContainer();
      final gate = Completer<bool>();
      ping.gate = gate;

      connectivity.add([ConnectivityResult.wifi]); // fires ping, held in flight
      await pumpEventQueue();
      container.read(connectivityControllerProvider.notifier).markSyncing();

      gate.complete(false); // pre-sync ping resolves (failed) after markSyncing
      await pumpEventQueue();

      expect(container.read(connectivityControllerProvider).status,
          ConnStatus.syncing,
          reason: 'a ping fired before the sync round is stale — only fresh '
              'signals may demote syncing');
    });

    test(
        'a FRESH failed ping (fired after sync started) DOES demote '
        'syncing → offline', () {
      fakeAsync((fake) {
        final container = makeContainer();
        ping.result = true;
        connectivity.add([ConnectivityResult.wifi]);
        fake.flushMicrotasks();
        final notifier =
            container.read(connectivityControllerProvider.notifier);
        notifier.markSyncing();

        ping.result = false; // connectivity genuinely lost mid-sync
        fake.elapse(const Duration(seconds: 30)); // fresh periodic tick

        expect(container.read(connectivityControllerProvider).status,
            ConnStatus.offline,
            reason: 'a fresh failed ping means the API became unreachable '
                'DURING the sync round — same semantics as losing the network');
      });
    });
  });

  test('an error on the connectivity stream is treated as offline', () async {
    final container = makeContainer();
    ping.result = true;
    connectivity.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.online);

    connectivity.addError(Exception('platform channel died'));
    await pumpEventQueue();

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
  });

  test('disposing the container cancels the timer (no pending-timer leak)',
      () {
    fakeAsync((fake) {
      // Built by hand (not makeContainer) so we control the single dispose().
      final container = ProviderContainer(overrides: [
        connectivityStreamProvider.overrideWithValue(connectivity.stream),
        healthPingProvider.overrideWithValue(ping.call),
        // Bootstrap neutro: este teste só olha o timer do caminho do stream.
        connectivityCheckProvider.overrideWithValue(() => initialCheck.future),
      ]);
      container.read(connectivityControllerProvider); // build() ⇒ subscribes
      ping.result = true;
      connectivity.add([ConnectivityResult.wifi]);
      fake.flushMicrotasks();
      final before = ping.callCount;
      expect(before, 1);

      container.dispose();
      fake.elapse(const Duration(minutes: 5)); // 10 ticks, se o timer vazasse

      expect(ping.callCount, before,
          reason: 'dispose cancela o Timer.periodic — nenhum ping depois');
    });
  });
}
