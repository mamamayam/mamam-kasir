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
    if (state.isLocked) return;
    if (state.enteredDigits.length >= PinAuthState.pinLength) return;

    final next = state.enteredDigits + digit;
    state = state.copyWith(enteredDigits: next, isError: false);

    if (next.length == PinAuthState.pinLength) {
      _verify(next);
    }
  }

  void backspace() {
    if (state.isLocked) return;
    if (state.enteredDigits.isEmpty) return;
    state = state.copyWith(
      enteredDigits: state.enteredDigits.substring(0, state.enteredDigits.length - 1),
      isError: false,
    );
  }

  Future<void> _verify(String pin) async {
    final result = await _repository.verifyPin(_userId, pin);
    if (!mounted) return;

    switch (result) {
      case PinVerifyResult.correct:
        state = state.copyWith(isError: false, failedAttempts: 0);
      case PinVerifyResult.incorrect:
        state = state.copyWith(enteredDigits: '', isError: true, failedAttempts: state.failedAttempts + 1);
      case PinVerifyResult.justLocked:
      case PinVerifyResult.alreadyLocked:
        // Both end in the same visible state — the PIN screen doesn't
        // distinguish "you just got locked" from "you were already
        // locked when you tried" (see PinVerifyResult's doc comment on
        // alreadyLocked: attempts against an already-locked account are
        // rejected without even checking the PIN, so there is nothing
        // more specific to tell the user in that case anyway).
        state = state.copyWith(enteredDigits: '', isError: true, isLocked: true);
    }
  }

  void reset() {
    state = const PinAuthState();
  }
}
