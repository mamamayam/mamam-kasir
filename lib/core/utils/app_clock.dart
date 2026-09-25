/// Injectable clock so time-dependent logic (PIN lockout duration,
/// auto-lock timers, the 3-day-no-PIN rule) can be tested without
/// waiting on real wall-clock time.
///
/// Built in A2 for [PinAuthRepository]'s lockout timing; A3's auto-lock
/// and 3-day rules should reuse this same abstraction rather than each
/// introducing their own `DateTime.now()` call, so both can be
/// controlled by the same fake clock in tests.
abstract class AppClock {
  DateTime now();

  /// The real system clock — used everywhere in production.
  static const AppClock system = _SystemClock();
}

class _SystemClock implements AppClock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test double: returns a fixed (or manually-advanced) time instead of
/// the real clock. Not used by app code — only by tests.
class FakeClock implements AppClock {
  DateTime _current;

  FakeClock(this._current);

  @override
  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void set(DateTime time) {
    _current = time;
  }
}
