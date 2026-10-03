import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pin_auth_repository.dart';
import '../domain/pin_auth_state.dart';

final pinAuthRepositoryProvider = Provider<PinAuthRepository>((ref) => PinAuthRepository());

/// Keyed by userId — A2's per-user PIN model means two different users
/// need two completely independent controllers/states (different
/// enteredDigits, different lockout), not one shared controller like
/// the old device-wide version. Still `.autoDispose` (UI-only state;
/// the actual lockout persistence lives in PinAuthRepository/the DB, not
/// here), but `.family` so switching users (via "Login dengan akun
/// lain") never reuses another user's leftover in-memory state.
final pinAuthControllerProvider =
    StateNotifierProvider.autoDispose.family<PinAuthController, PinAuthState, String>(
  (ref, userId) => PinAuthController(ref.watch(pinAuthRepositoryProvider), userId)..loadInitialLockState(),
);

class PinAuthController extends StateNotifier<PinAuthState> {
  final PinAuthRepository _repository;
  final String _userId;

  PinAuthController(this._repository, this._userId) : super(const PinAuthState());

  /// Reads the persisted lock state from the DB as soon as this
  /// controller is created, so a user who was already locked (e.g. app
  /// was killed mid-lockout, or they navigated away and back) sees the
  /// locked state immediately rather than starting from a fresh
  /// isLocked=false — this is what makes lockout survive "restart"
  /// rather than living only in this autoDispose controller's memory.
  Future<void> loadInitialLockState() async {
    final identity = await _repository.loadIdentity(_userId);
    if (!mounted || identity == null) return;
    if (identity.isLocked) {
      state = state.copyWith(isLocked: true);
    }
  }

  void addDigit(String digit) {
    // Ignore input while locked, while a check is in flight, or once
    // already verified — otherwise a 5th tap during the async check
    // could start a second verification for the same entry.
    if (state.isLocked || state.isVerifying || state.isVerified) return;
    if (state.enteredDigits.length >= PinAuthState.pinLength) return;

    final next = state.enteredDigits + digit;
    final isComplete = next.length == PinAuthState.pinLength;
    // isVerifying goes true in the SAME state update that fills the 4th
    // digit, so there is never a moment where "4 digits, no error, not
    // locked" is visible without also saying "still checking".
    state = state.copyWith(enteredDigits: next, isError: false, isVerifying: isComplete);

    if (isComplete) {
      _verify(next);
    }
  }

  void backspace() {
    if (state.isLocked || state.isVerifying || state.isVerified) return;
    if (state.enteredDigits.isEmpty) return;
    state = state.copyWith(
      enteredDigits: state.enteredDigits.substring(0, state.enteredDigits.length - 1),
      isError: false,
    );
  }

  Future<void> _verify(String pin) async {
    final PinVerifyResult result;
    try {
      result = await _repository.verifyPin(_userId, pin);
    } catch (_) {
      // The check itself failed (e.g. database error). That is NOT a
      // successful PIN — fail closed: show it as a rejected attempt and
      // let the user try again. Never fall through to "verified".
      if (!mounted) return;
      state = state.copyWith(enteredDigits: '', isError: true, isVerifying: false);
      return;
    }
    if (!mounted) return;

    switch (result) {
      case PinVerifyResult.correct:
        // The ONLY place isVerified becomes true.
        state = state.copyWith(isError: false, isVerifying: false, isVerified: true, failedAttempts: 0);
      case PinVerifyResult.incorrect:
        state = state.copyWith(
          enteredDigits: '',
          isError: true,
          isVerifying: false,
          failedAttempts: state.failedAttempts + 1,
        );
      case PinVerifyResult.justLocked:
      case PinVerifyResult.alreadyLocked:
        // Both end in the same visible state — the PIN screen doesn't
        // distinguish "you just got locked" from "you were already
        // locked when you tried" (see PinVerifyResult's doc comment on
        // alreadyLocked: attempts against an already-locked account are
        // rejected without even checking the PIN, so there is nothing
        // more specific to tell the user in that case anyway).
        state = state.copyWith(enteredDigits: '', isError: true, isVerifying: false, isLocked: true);
    }
  }

  void reset() {
    state = const PinAuthState();
  }
}
