import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../domain/pin_auth_state.dart';

final pinAuthControllerProvider =
    StateNotifierProvider.autoDispose<PinAuthController, PinAuthState>(
  (ref) => PinAuthController(ref),
);

class PinAuthController extends StateNotifier<PinAuthState> {
  final Ref _ref;

  PinAuthController(this._ref) : super(const PinAuthState());

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
    final isCorrect = await _ref.read(appSessionProvider.notifier).verifyPin(pin);
    if (!mounted) return;

    if (isCorrect) {
      state = state.copyWith(isError: false, failedAttempts: 0);
      return;
    }

    final attempts = state.failedAttempts + 1;
    final locked = attempts >= PinAuthState.maxAttempts;
    state = state.copyWith(
      enteredDigits: '',
      isError: true,
      failedAttempts: attempts,
      isLocked: locked,
    );
  }

  void reset() {
    state = const PinAuthState();
  }
}
