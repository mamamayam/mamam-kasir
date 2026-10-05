/// UI-facing state for the PIN pad. Deliberately dumb/presentational —
/// real PIN verification, lockout persistence, and 3-day-inactivity ->
/// credential fallback (per AGENTS.md security rules) belong in the
/// application/domain layer once auth module (docs/06 phase 3) is built.
class PinAuthState {
  final String enteredDigits;
  final bool isError;
  final bool isLocked;
  final int failedAttempts;

  /// True from the moment the last digit is entered until the PIN check
  /// (an async DB lookup) has answered. The keypad must stay disabled
  /// while this is true.
  final bool isVerifying;

  /// True ONLY after the PIN check has explicitly answered "correct".
  /// This is the one and only signal the PIN screen may navigate on.
  ///
  /// It exists because success used to be INFERRED from "4 digits
  /// entered, no error, not locked" — but that exact state also occurs
  /// for the instant between typing the 4th digit and the check
  /// answering, so every PIN looked like a success and any random 4
  /// digits logged in. Never derive success from enteredDigits again.
  final bool isVerified;

  const PinAuthState({
    this.enteredDigits = '',
    this.isError = false,
    this.isLocked = false,
    this.failedAttempts = 0,
    this.isVerifying = false,
    this.isVerified = false,
  });

  static const int maxAttempts = 5;
  static const int pinLength = 4;

  PinAuthState copyWith({
    String? enteredDigits,
    bool? isError,
    bool? isLocked,
    int? failedAttempts,
    bool? isVerifying,
    bool? isVerified,
  }) {
    return PinAuthState(
      enteredDigits: enteredDigits ?? this.enteredDigits,
      isError: isError ?? this.isError,
      isLocked: isLocked ?? this.isLocked,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      isVerifying: isVerifying ?? this.isVerifying,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
