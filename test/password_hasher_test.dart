// Tests for PasswordHasher (lib/core/data/password_hasher.dart).
//
// Pure Dart logic (crypto package only, no sqflite/platform channel), so
// unlike the DB-dependent tests in app_database_test.dart, this file can
// run with a plain `flutter test` (or even `dart test`) without needing
// a device/emulator or sqflite's FFI setup.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('generateSalt produces a non-empty, non-deterministic value', () {
      final saltA = PasswordHasher.generateSalt();
      final saltB = PasswordHasher.generateSalt();

      expect(saltA, isNotEmpty);
      expect(saltB, isNotEmpty);
      expect(saltA, isNot(equals(saltB)));
    });

    test('hash is deterministic for the same input+salt', () {
      final salt = PasswordHasher.generateSalt();
      final hashA = PasswordHasher.hash('owner123', salt);
      final hashB = PasswordHasher.hash('owner123', salt);

      expect(hashA, equals(hashB));
    });

    test('hash differs for different salts, same plaintext', () {
      final hashA = PasswordHasher.hash('owner123', PasswordHasher.generateSalt());
      final hashB = PasswordHasher.hash('owner123', PasswordHasher.generateSalt());

      // Vanishingly unlikely to collide with random 16-byte salts —
      // this is the property that defeats rainbow-table lookups.
      expect(hashA, isNot(equals(hashB)));
    });

    test('verify succeeds for the correct plaintext+salt pair', () {
      final salt = PasswordHasher.generateSalt();
      final expectedHash = PasswordHasher.hash('staff123', salt);

      final result = PasswordHasher.verify(
        plainText: 'staff123',
        salt: salt,
        expectedHash: expectedHash,
      );

      expect(result, isTrue);
    });

    test('verify fails for wrong plaintext', () {
      final salt = PasswordHasher.generateSalt();
      final expectedHash = PasswordHasher.hash('staff123', salt);

      final result = PasswordHasher.verify(
        plainText: 'wrong-password',
        salt: salt,
        expectedHash: expectedHash,
      );

      expect(result, isFalse);
    });

    test('verify fails when salt does not match the one used to hash', () {
      final saltUsedToHash = PasswordHasher.generateSalt();
      final expectedHash = PasswordHasher.hash('staff123', saltUsedToHash);
      final differentSalt = PasswordHasher.generateSalt();

      final result = PasswordHasher.verify(
        plainText: 'staff123',
        salt: differentSalt,
        expectedHash: expectedHash,
      );

      expect(result, isFalse);
    });

    test('works identically for 4-digit PINs, same as passwords', () {
      // PasswordHasher is used for both users.password_hash/salt and
      // users.pin_hash/salt (see its doc comment) — this test just
      // confirms nothing about it assumes password-length input.
      final salt = PasswordHasher.generateSalt();
      final expectedHash = PasswordHasher.hash('1234', salt);

      expect(PasswordHasher.verify(plainText: '1234', salt: salt, expectedHash: expectedHash), isTrue);
      expect(PasswordHasher.verify(plainText: '4321', salt: salt, expectedHash: expectedHash), isFalse);
    });
  });
}
