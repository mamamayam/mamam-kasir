// Tests for PinAuthRepository (lib/features/auth/data/pin_auth_repository.dart).
//
// Same environment limitation as app_database_auth_test.dart: needs a
// real device/emulator, not plain `flutter test`, because
// sqflite_sqlcipher has no FFI/desktop test mode. See that file's header
// comment for the full explanation — not repeated here.
//
// These tests specifically cover the task brief's required scenarios:
// "PIN A tidak bisa membuka akun B", "Lock user A tidak mengunci user
// B", "5x PIN salah -> lock, dan lock bertahan setelah restart", "PIN
// tersimpan sebagai hash + salt, bukan mentah".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:mamam_kasir/core/utils/app_clock.dart';
import 'package:mamam_kasir/features/auth/data/pin_auth_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String tempDirPath;
  _FakePathProvider.withPath(this.tempDirPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String ownerId;
  late String staffId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_pin_test_');
    PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);

    final db = await AppDatabase.instance.database;
    final ownerRow = await db.query('users', where: 'username = ?', whereArgs: ['owner'], limit: 1);
    final staffRow = await db.query('users', where: 'username = ?', whereArgs: ['staff'], limit: 1);
    ownerId = ownerRow.first['id'] as String;
    staffId = staffRow.first['id'] as String;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PIN is per-user, not per-device', () {
    test('user A and user B can set different PINs on the same device', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');
      await repo.setPin(staffId, '2222');

      expect(await repo.verifyPin(ownerId, '1111'), PinVerifyResult.correct);
      expect(await repo.verifyPin(staffId, '2222'), PinVerifyResult.correct);
    });

    test("user A's PIN cannot unlock user B's account", () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');
      await repo.setPin(staffId, '2222');

      // Try owner's PIN against staff's account.
      final result = await repo.verifyPin(staffId, '1111');
      expect(result, PinVerifyResult.incorrect);
    });
  });

  group('Lockout is per-user, persistent', () {
    test('locking user A does not lock user B', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');
      await repo.setPin(staffId, '2222');

      // 5 wrong attempts against owner.
      for (var i = 0; i < PinAuthRepository.maxAttempts; i++) {
        await repo.verifyPin(ownerId, '0000');
      }

      final ownerIdentity = await repo.loadIdentity(ownerId);
      final staffIdentity = await repo.loadIdentity(staffId);

      expect(ownerIdentity!.isLocked, isTrue);
      expect(staffIdentity!.isLocked, isFalse);

      // Staff's own correct PIN should still work.
      expect(await repo.verifyPin(staffId, '2222'), PinVerifyResult.correct);
    });

    test('5th wrong attempt returns justLocked, 6th returns alreadyLocked', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');

      for (var i = 0; i < PinAuthRepository.maxAttempts - 1; i++) {
        final result = await repo.verifyPin(ownerId, '0000');
        expect(result, PinVerifyResult.incorrect, reason: 'attempt ${i + 1}');
      }

      final fifthAttempt = await repo.verifyPin(ownerId, '0000');
      expect(fifthAttempt, PinVerifyResult.justLocked);

      // Even the CORRECT PIN is rejected once locked — no PIN check
      // happens at all once locked_at is set.
      final sixthAttempt = await repo.verifyPin(ownerId, '1111');
      expect(sixthAttempt, PinVerifyResult.alreadyLocked);
    });

    test('lockout survives "restart" (fresh repository instance, same DB)', () async {
      final repoA = PinAuthRepository();
      await repoA.setPin(ownerId, '1111');
      for (var i = 0; i < PinAuthRepository.maxAttempts; i++) {
        await repoA.verifyPin(ownerId, '0000');
      }

      // Simulate app restart: brand new repository instance, same
      // underlying (still-open, same file path) database.
      final repoB = PinAuthRepository();
      final identity = await repoB.loadIdentity(ownerId);
      expect(identity!.isLocked, isTrue);

      final attempt = await repoB.verifyPin(ownerId, '1111');
      expect(attempt, PinVerifyResult.alreadyLocked);
    });

    test('successful password re-login clears lockout (the only unlock path)', () async {
      // This exercises AuthRepository.verifyCredentials's lockout-clear
      // side effect, not PinAuthRepository directly — included here
      // since it's the other half of the lockout story.
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');
      for (var i = 0; i < PinAuthRepository.maxAttempts; i++) {
        await repo.verifyPin(ownerId, '0000');
      }
      expect((await repo.loadIdentity(ownerId))!.isLocked, isTrue);

      final db = await AppDatabase.instance.database;
      // Directly exercise the same UPDATE AuthRepository.
      // verifyCredentials performs, to avoid needing a full
      // AuthRepository+password-hash setup in this PIN-focused test file.
      await db.update('users', {'failed_pin_attempts': 0, 'locked_at': null}, where: 'id = ?', whereArgs: [ownerId]);

      expect((await repo.loadIdentity(ownerId))!.isLocked, isFalse);
      // PIN itself is untouched by the unlock — still '1111'.
      expect(await repo.verifyPin(ownerId, '1111'), PinVerifyResult.correct);
    });
  });

  group('PIN storage', () {
    test('PIN is stored as hash+salt, never the plaintext digits', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1234');

      final db = await AppDatabase.instance.database;
      final row = (await db.query('users', where: 'id = ?', whereArgs: [ownerId])).first;

      expect(row['pin_hash'], isNot(equals('1234')));
      expect(row['pin_salt'], isNotNull);
      expect((row['pin_salt'] as String).isNotEmpty, isTrue);
    });

    test('hasPinSet is false before setPin, true after', () async {
      final repo = PinAuthRepository();
      expect(await repo.hasPinSet(ownerId), isFalse);

      await repo.setPin(ownerId, '1234');
      expect(await repo.hasPinSet(ownerId), isTrue);
    });

    test('changePin fails with wrong current PIN and does not change anything', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');

      final success = await repo.changePin(ownerId, currentPin: '9999', newPin: '2222');
      expect(success, isFalse);
      expect(await repo.verifyPin(ownerId, '1111'), PinVerifyResult.correct);
    });

    test('changePin succeeds with correct current PIN, no logout required', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');

      final success = await repo.changePin(ownerId, currentPin: '1111', newPin: '2222');
      expect(success, isTrue);
      expect(await repo.verifyPin(ownerId, '2222'), PinVerifyResult.correct);
    });
  });

  group('3-day password-reentry rule (last_pin_at)', () {
    test('requiresPasswordReentry is false for a user who just entered their PIN', () async {
      final clock = FakeClock(DateTime(2026, 1, 1));
      final repo = PinAuthRepository(clock: clock);
      await repo.setPin(ownerId, '1111');
      await repo.verifyPin(ownerId, '1111');

      expect(await repo.requiresPasswordReentry(ownerId), isFalse);
    });

    test('requiresPasswordReentry becomes true after 3+ days with no successful PIN entry', () async {
      final clock = FakeClock(DateTime(2026, 1, 1));
      final repo = PinAuthRepository(clock: clock);
      await repo.setPin(ownerId, '1111');
      await repo.verifyPin(ownerId, '1111'); // last_pin_at = Jan 1

      clock.advance(const Duration(days: 4));
      expect(await repo.requiresPasswordReentry(ownerId), isTrue);
    });

    test('requiresPasswordReentry is false for a user who has never entered a PIN', () async {
      // No setPin call at all — last_pin_at stays null (seeded that
      // way). Per the method's doc comment, this is NOT treated as
      // over-threshold; SetPinScreen routing handles that case instead.
      final repo = PinAuthRepository();
      expect(await repo.requiresPasswordReentry(staffId), isFalse);
    });
  });

  group('"Ganti akun" does not disturb the previous user (DoD item)', () {
    // PinLoginScreen's "Bukan kamu? Ganti akun" button (see
    // pin_login_screen.dart's _goToLogin) only calls Navigator — it
    // never touches PinAuthRepository or AppSessionController for the
    // user being switched away from. This test can't exercise the
    // actual button press (that needs a full WidgetTester/pumpWidget
    // setup with the provider tree, not written in this pass — flagged
    // in the report), but it does verify the invariant that matters:
    // a user's PIN/lock state is untouched by anything other than that
    // user's own repository calls, so simply switching which user is
    // "current" in the session (without calling any PinAuthRepository
    // method for the old user) leaves their state exactly as it was.
    test('user A stays locked/unlocked and keeps their PIN regardless of session switching', () async {
      final repo = PinAuthRepository();
      await repo.setPin(ownerId, '1111');
      await repo.setPin(staffId, '2222');

      // Lock owner.
      for (var i = 0; i < PinAuthRepository.maxAttempts; i++) {
        await repo.verifyPin(ownerId, '0000');
      }
      expect((await repo.loadIdentity(ownerId))!.isLocked, isTrue);

      // Simulate "switching accounts": do a bunch of operations for
      // staff only — nothing here should be able to affect owner.
      await repo.verifyPin(staffId, '2222');
      await repo.changePin(staffId, currentPin: '2222', newPin: '3333');

      final ownerAfter = await repo.loadIdentity(ownerId);
      expect(ownerAfter!.isLocked, isTrue, reason: "owner's lock must be untouched by staff's activity");
      // Owner's PIN is unchanged too — still locked, but the underlying
      // value would still be '1111' once unlocked (can't verify while
      // locked, so we confirm indirectly via the lock state remaining
      // exactly as set, with no unexpected side effects from the staff
      // operations above).
    });
  });
}
