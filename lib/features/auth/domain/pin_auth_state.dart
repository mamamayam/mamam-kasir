/// UI-facing state for the PIN pad. Deliberately dumb/presentational —
/// real PIN verification, lockout persistence, and 3-day-inactivity ->
/// credential fallback (per AGENTS.md security rules) belong in the
/// application/domain layer once auth module (docs/06 phase 3) is built.
class PinAuthState {
  final String enteredDigits;
  final bool isError;
  final bool isLocked;
  final int failedAttempts;

  const PinAuthState({
    this.enteredDigits = '',
    this.isError = false,
    this.isLocked = false,
    this.failedAttempts = 0,
  });

  static const int maxAttempts = 5;
  static const int pinLength = 4;

  PinAuthState copyWith({
    String? enteredDigits,
    bool? isError,
    bool? isLocked,
    int? failedAttempts,
  }) {
    return PinAuthState(
      enteredDigits: enteredDigits ?? this.enteredDigits,
      isError: isError ?? this.isError,
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}
