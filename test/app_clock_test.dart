// Tests for AppClock/FakeClock (lib/core/utils/app_clock.dart).
// Pure Dart, no DB/platform binding — runs with plain `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/utils/app_clock.dart';

void main() {
  group('FakeClock', () {
    test('now() returns the fixed time it was constructed with', () {
      final fixed = DateTime(2026, 1, 1, 12, 0, 0);
      final clock = FakeClock(fixed);

      expect(clock.now(), fixed);
    });

    test('advance() moves the clock forward by the given duration', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 12, 0, 0));
      clock.advance(const Duration(days: 3));

      expect(clock.now(), DateTime(2026, 1, 4, 12, 0, 0));
    });

    test('set() jumps the clock to an arbitrary time', () {
      final clock = FakeClock(DateTime(2026, 1, 1));
      clock.set(DateTime(2030, 6, 15));

      expect(clock.now(), DateTime(2030, 6, 15));
    });

    test('multiple advance() calls accumulate', () {
      final clock = FakeClock(DateTime(2026, 1, 1));
      clock.advance(const Duration(hours: 20));
      clock.advance(const Duration(hours: 20));

      // 40 hours later = 1 day 16 hours later.
      expect(clock.now(), DateTime(2026, 1, 2, 16, 0, 0));
    });
  });

  group('AppClock.system', () {
    test('now() returns a time close to the real current time', () {
      final before = DateTime.now();
      final result = AppClock.system.now();
      final after = DateTime.now();

      expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
