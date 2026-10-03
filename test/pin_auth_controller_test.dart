// Regression tests for PinAuthController (the PIN screen's state).
//
// The bug these guard against: the PIN screen used to treat "4 digits
// entered, no error, not locked" as SUCCESS — but that is also exactly
// the state for the instant between typing the 4th digit and the async
// PIN check answering. So ANY 4 digits looked correct and logged in,
// while the real check (and its wrong-attempt counting) ran unseen in
// the background.
//
// Pure Dart: the repository is faked, so there is no database, and this
// runs with plain `flutter test`.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
import 'package:mamam_kasir/features/auth/data/pin_auth_repository.dart';
import 'package:mamam_kasir/features/auth/domain/pin_auth_state.dart';
import 'package:mamam_kasir/features/auth/domain/pin_user_identity.dart';
import 'package:mamam_kasir/features/auth/presentation/pin_auth_controller.dart';

/// Mimics the real repository's contract: correct PIN -> correct; wrong
/// PIN -> incorrect, and the 5th wrong one locks (justLocked), after
/// which everything — even the right PIN — is alreadyLocked.
class _FakePinAuthRepository extends PinAuthRepository {
  _FakePinAuthRepository({this.correctPin = '1234', this.startsLocked = false});

  final String correctPin;
  final bool startsLocked;

  int verifyCalls = 0;
  int _wrongCount = 0;
  bool _locked = false;

  /// When set, verifyPin waits on this before answering — lets a test
  /// look at the state DURING the check.
  Completer<void>? gate;
  bool throwOnVerify = false;

  @override
  Future<PinUserIdentity?> loadIdentity(String userId) async {
    return PinUserIdentity(userId: userId, displayName: 'Test', role: AppRole.staff, isLocked: startsLocked);
  }

  @override
  Future<PinVerifyResult> verifyPin(String userId, String pin) async {
    verifyCalls++;
    if (gate != null) await gate!.future;
    if (throwOnVerify) throw StateError('simulated database failure');
    if (startsLocked || _locked) return PinVerifyResult.alreadyLocked;
    if (pin == correctPin) {
      _wrongCount = 0;
      return PinVerifyResult.correct;
    }
    _wrongCount++;
    if (_wrongCount >= PinAuthRepository.maxAttempts) {
      _locked = true;
      return PinVerifyResult.justLocked;
    }
    return PinVerifyResult.incorrect;
  }
}

const _userId = 'user-1';

({ProviderContainer container, PinAuthController controller}) _setUp(_FakePinAuthRepository fake) {
  final container = ProviderContainer(overrides: [pinAuthRepositoryProvider.overrideWithValue(fake)]);
  addTearDown(container.dispose);
  // autoDispose provider: hold a listener so it isn't disposed mid-test.
  container.listen(pinAuthControllerProvider(_userId), (_, __) {});
  return (container: container, controller: container.read(pinAuthControllerProvider(_userId).notifier));
}

PinAuthState _state(ProviderContainer c) => c.read(pinAuthControllerProvider(_userId));

void _enter(PinAuthController controller, String digits) {
  for (final d in digits.split('')) {
    controller.addDigit(d);
  }
}

void main() {
  group('a PIN is never "verified" before the check answers', () {
    test('right after the 4th digit: verifying, NOT verified (this was the bug)', () async {
      final fake = _FakePinAuthRepository()..gate = Completer<void>();
      final t = _setUp(fake);
      await pumpEventQueue();

      _enter(t.controller, '9999'); // a wrong PIN, check still pending

      expect(_state(t.container).enteredDigits.length, PinAuthState.pinLength);
      expect(_state(t.container).isVerifying, isTrue);
      expect(_state(t.container).isVerified, isFalse, reason: 'must not look like success while the check is still running');

      fake.gate!.complete();
      await pumpEventQueue();

      expect(_state(t.container).isVerified, isFalse, reason: 'a wrong PIN must never end up verified');
      expect(_state(t.container).isError, isTrue);
      expect(_state(t.container).isVerifying, isFalse);
      expect(_state(t.container).enteredDigits, isEmpty, reason: 'digits are cleared after a wrong PIN');
    });

    test('the correct PIN becomes verified only once the check has said so', () async {
      final fake = _FakePinAuthRepository()..gate = Completer<void>();
      final t = _setUp(fake);
      await pumpEventQueue();

      _enter(t.controller, '1234');
      expect(_state(t.container).isVerified, isFalse);

      fake.gate!.complete();
      await pumpEventQueue();

      expect(_state(t.container).isVerified, isTrue);
      expect(_state(t.container).isVerifying, isFalse);
      expect(_state(t.container).isError, isFalse);
    });

    test('a batch of random wrong PINs: none of them ever verifies', () async {
      final fake = _FakePinAuthRepository();
      final t = _setUp(fake);
      await pumpEventQueue();

      // 4 attempts stays under the 5-attempt lock, so this isolates
      // "wrong PIN never verifies" from the lock behaviour below.
      for (final wrong in ['0000', '1111', '4321', '5678']) {
        _enter(t.controller, wrong);
        await pumpEventQueue();
        expect(_state(t.container).isVerified, isFalse, reason: '$wrong must not verify');
        expect(_state(t.container).isError, isTrue);
      }
    });
  });

  group('input handling', () {
    test('extra taps while a check is running are ignored (no second verification)', () async {
      final fake = _FakePinAuthRepository()..gate = Completer<void>();
      final t = _setUp(fake);
      await pumpEventQueue();

      _enter(t.controller, '9999');
      t.controller.addDigit('1'); // tapped while verifying
      t.controller.addDigit('2');
      t.controller.backspace();

      expect(_state(t.container).enteredDigits, '9999');
      expect(fake.verifyCalls, 1);

      fake.gate!.complete();
      await pumpEventQueue();
    });

    test('after a wrong PIN the user can simply try again', () async {
      final fake = _FakePinAuthRepository();
      final t = _setUp(fake);
      await pumpEventQueue();

      _enter(t.controller, '0000');
      await pumpEventQueue();
      expect(_state(t.container).isVerified, isFalse);

      _enter(t.controller, '1234');
      await pumpEventQueue();
      expect(_state(t.container).isVerified, isTrue);
    });
  });

  group('lockout', () {
    test('the 5th wrong PIN locks; after that even the right PIN cannot get in', () async {
      final fake = _FakePinAuthRepository();
      final t = _setUp(fake);
      await pumpEventQueue();

      for (var i = 0; i < PinAuthState.maxAttempts; i++) {
        _enter(t.controller, '0000');
        await pumpEventQueue();
      }

      expect(_state(t.container).isLocked, isTrue);
      expect(_state(t.container).isVerified, isFalse);

      final callsBefore = fake.verifyCalls;
      _enter(t.controller, '1234'); // the CORRECT PIN, but locked
      await pumpEventQueue();

      expect(_state(t.container).isVerified, isFalse);
      expect(fake.verifyCalls, callsBefore, reason: 'a locked keypad does not even start a check');
    });

    test('an account that was already locked when the screen opened shows as locked', () async {
      final fake = _FakePinAuthRepository(startsLocked: true);
      final t = _setUp(fake);
      await pumpEventQueue();

      expect(_state(t.container).isLocked, isTrue);

      _enter(t.controller, '1234');
      await pumpEventQueue();
      expect(_state(t.container).isVerified, isFalse);
    });
  });

  group('failures fail closed', () {
    test('if the PIN check itself errors, the attempt is rejected — never treated as success', () async {
      final fake = _FakePinAuthRepository()..throwOnVerify = true;
      final t = _setUp(fake);
      await pumpEventQueue();

      _enter(t.controller, '1234');
      await pumpEventQueue();

      expect(_state(t.container).isVerified, isFalse);
      expect(_state(t.container).isError, isTrue);
      expect(_state(t.container).isVerifying, isFalse, reason: 'the keypad must not stay stuck disabled');
    });
  });
}
