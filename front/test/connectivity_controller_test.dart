import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/connectivity_controller.dart';
import 'package:orbixhub_front/di.dart';

/// Controllable stand-in for `connectivity_plus`'s stream + a fake `/health`
/// ping — no platform channel and no real HTTP call in these tests.
class _FakePing {
  bool result = true;
  int callCount = 0;

  Future<bool> call() async {
    callCount++;
    return result;
  }
}

void main() {
  late StreamController<List<ConnectivityResult>> connectivity;
  late _FakePing ping;

  ProviderContainer makeContainer({Duration? pingInterval}) {
    final c = ProviderContainer(overrides: [
      connectivityStreamProvider.overrideWithValue(connectivity.stream),
      healthPingProvider.overrideWithValue(ping.call),
      if (pingInterval != null) pingIntervalProvider.overrideWithValue(pingInterval),
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
  });

  test('starts offline before any connectivity signal arrives', () {
    final container = makeContainer();
    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.offline);
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

  test('pings again periodically while the network stays up', () async {
    final container = makeContainer(pingInterval: const Duration(milliseconds: 20));
    ping.result = true;
    connectivity.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    final afterFirst = ping.callCount;
    expect(afterFirst, greaterThanOrEqualTo(1));

    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(container.read(connectivityControllerProvider).status,
        ConnStatus.online);
    expect(ping.callCount, greaterThan(afterFirst),
        reason: 'the 30s-equivalent periodic ping must keep firing');
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

  test('disposing the container cancels the timer (no pending-timer leak)',
      () async {
    // Built by hand (not makeContainer) so we control the single dispose().
    final container = ProviderContainer(overrides: [
      connectivityStreamProvider.overrideWithValue(connectivity.stream),
      healthPingProvider.overrideWithValue(ping.call),
      pingIntervalProvider.overrideWithValue(const Duration(milliseconds: 10)),
    ]);
    container.read(connectivityControllerProvider); // build() ⇒ subscribes
    ping.result = true;
    connectivity.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    container.dispose();
    // If the periodic timer weren't cancelled, this delay would let it fire
    // again after disposal and `flutter test` would report a pending timer.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
}
