import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/network/single_flight_refresher.dart';

void main() {
  group('SingleFlightRefresher (criterion 2: single-flight refresh)', () {
    test('N concurrent 401s collapse into ONE refresh; all share the result',
        () async {
      var performCalls = 0;
      final gate = Completer<bool>();
      final refresher = SingleFlightRefresher(() async {
        performCalls++;
        return gate.future;
      });

      // Five requests hit 401 "at the same time".
      final futures = List.generate(5, (_) => refresher.refresh());
      gate.complete(true);
      final results = await Future.wait(futures);

      expect(performCalls, 1, reason: 'only one refresh call may be in flight');
      expect(refresher.performCount, 1);
      expect(results, everyElement(isTrue));
    });

    test('a new refresh is allowed once the previous settles', () async {
      var performCalls = 0;
      final refresher = SingleFlightRefresher(() async {
        performCalls++;
        return true;
      });

      await refresher.refresh();
      await refresher.refresh();

      expect(performCalls, 2);
    });

    test('propagates failure to all concurrent waiters', () async {
      final gate = Completer<bool>();
      final refresher = SingleFlightRefresher(() => gate.future);

      final futures = List.generate(3, (_) => refresher.refresh());
      gate.complete(false);
      final results = await Future.wait(futures);

      expect(results, everyElement(isFalse));
    });
  });
}
