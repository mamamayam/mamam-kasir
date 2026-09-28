// Tests for shouldAutoLock (lib/core/session/app_lifecycle_guard.dart).
// Pure Dart logic, no Flutter widget tree or DB — runs with plain
// `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/session/app_lifecycle_guard.dart';

void main() {
  group('shouldAutoLock', () {
    test('returns false when elapsed time is under the threshold', () {
      final backgroundedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = backgroundedAt.add(const Duration(minutes: 29, seconds: 59));

      expect(shouldAutoLock(backgroundedAt: backgroundedAt, now: now), isFalse);
    });

    test('returns true exactly at the threshold', () {
      final backgroundedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = backgroundedAt.add(kAutoLockThreshold);

      expect(shouldAutoLock(backgroundedAt: backgroundedAt, now: now), isTrue);
    });

    test('returns true well past the threshold (e.g. overnight)', () {
      final backgroundedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = backgroundedAt.add(const Duration(hours: 10));

      expect(shouldAutoLock(backgroundedAt: backgroundedAt, now: now), isTrue);
    });

    test('respects a custom threshold override', () {
      final backgroundedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final now = backgroundedAt.add(const Duration(minutes: 5));

      expect(
        shouldAutoLock(backgroundedAt: backgroundedAt, now: now, threshold: const Duration(minutes: 1)),
        isTrue,
        reason: '5 minutes elapsed should trigger a 1-minute threshold',
      );
      expect(
        shouldAutoLock(backgroundedAt: backgroundedAt, now: now, threshold: const Duration(hours: 1)),
        isFalse,
        reason: '5 minutes elapsed should not trigger a 1-hour threshold',
      );
    });

    test('kAutoLockThreshold is 30 minutes, matching AGENTS.md', () {
      expect(kAutoLockThreshold, const Duration(minutes: 30));
    });
  });
}
