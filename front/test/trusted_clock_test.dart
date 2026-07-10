import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/core/offline/trusted_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// S3 — relógio confiável (anti clock-rollback p/ login offline, usado pelo
/// B6): guarda o maior timestamp já observado (`max_seen_ts`) e expõe se o
/// relógio do device está para trás dele além de uma tolerância.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('observe', () {
    test('keeps the maximum timestamp ever observed', () async {
      final clock = TrustedClock();
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 6, 1);
      final earlier = DateTime.utc(2026, 3, 1);

      await clock.observe(t1);
      expect(clock.maxSeenTs, t1);

      await clock.observe(t2);
      expect(clock.maxSeenTs, t2, reason: 'later timestamp replaces the max');

      await clock.observe(earlier);
      expect(clock.maxSeenTs, t2,
          reason: 'an earlier timestamp must never lower the max');
    });

    test('persists max_seen_ts so a new instance restores it via load()',
        () async {
      final first = TrustedClock();
      final seen = DateTime.utc(2026, 5, 20, 12);
      await first.observe(seen);

      final second = TrustedClock();
      expect(second.maxSeenTs, isNull, reason: 'not loaded yet');
      await second.load();

      expect(second.maxSeenTs, seen);
    });

    test('load() does not clobber a max already observed in memory',
        () async {
      SharedPreferences.setMockInitialValues(
          {'orbix_trusted_clock_max_seen_ts': '2020-01-01T00:00:00.000Z'});
      final clock = TrustedClock();
      final newer = DateTime.utc(2026, 1, 1);
      await clock.observe(newer);

      await clock.load();

      expect(clock.maxSeenTs, newer);
    });
  });

  group('clockRolledBack', () {
    test('false when nothing has ever been observed', () {
      final clock = TrustedClock(clock: () => DateTime.utc(2026, 1, 1));
      expect(clock.clockRolledBack, isFalse);
    });

    test('false when device now is at/after the max seen', () async {
      final fixedNow = DateTime.utc(2026, 1, 1, 12);
      final clock = TrustedClock(clock: () => fixedNow);
      await clock.observe(fixedNow.subtract(const Duration(days: 1)));

      expect(clock.clockRolledBack, isFalse);
    });

    test('false within the 5-minute tolerance (legitimate clock adjustment)',
        () async {
      final fixedNow = DateTime.utc(2026, 1, 1, 12);
      final clock = TrustedClock(clock: () => fixedNow);
      // max seen is 3 minutes ahead of "now" — within tolerance.
      await clock.observe(fixedNow.add(const Duration(minutes: 3)));

      expect(clock.clockRolledBack, isFalse);
    });

    test('true when device now is behind the max seen beyond tolerance',
        () async {
      final fixedNow = DateTime.utc(2026, 1, 1, 12);
      final clock = TrustedClock(clock: () => fixedNow);
      // max seen is 10 minutes ahead of "now" — beyond the 5-minute tolerance.
      await clock.observe(fixedNow.add(const Duration(minutes: 10)));

      expect(clock.clockRolledBack, isTrue);
    });

    test('now exposes the injected/device clock', () {
      final fixedNow = DateTime.utc(2026, 2, 2);
      final clock = TrustedClock(clock: () => fixedNow);
      expect(clock.now, fixedNow);
    });

    test(
        'ready: after awaiting it on cold start, a persisted rollback is '
        'visible (no false negative before prefs load)', () async {
      // Persisted max is way ahead of the (rolled-back) device clock.
      SharedPreferences.setMockInitialValues({
        'orbix_trusted_clock_max_seen_ts':
            DateTime.utc(2026, 6, 1).toIso8601String(),
      });
      final clock = TrustedClock(clock: () => DateTime.utc(2026, 1, 1));

      await clock.ready;

      expect(clock.clockRolledBack, isTrue,
          reason: 'B6 awaits `ready` before trusting clockRolledBack — after '
              'that, a persisted rollback must never be missed');
      expect(clock.maxSeenTs, DateTime.utc(2026, 6, 1));
    });

    test('ready is the same memoized load (safe to await multiple times)',
        () async {
      SharedPreferences.setMockInitialValues({
        'orbix_trusted_clock_max_seen_ts':
            DateTime.utc(2026, 3, 1).toIso8601String(),
      });
      final clock = TrustedClock();

      await clock.ready;
      await clock.ready;
      await clock.load();

      expect(clock.maxSeenTs, DateTime.utc(2026, 3, 1));
    });
  });
}
