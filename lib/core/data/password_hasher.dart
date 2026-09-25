import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// SHA-256 + per-user random salt hashing for passwords and PINs.
///
/// Kept deliberately simple (not bcrypt/argon2, no configurable work
/// factor) — Tahap A decision: this app's credentials live in an
/// on-device encrypted SQLCipher database, not a server exposed to
/// remote brute-force, so a random salt defeating rainbow tables is
/// enough for this threat model. If that assumption ever changes
/// (e.g. these hashes get synced to a server), revisit with a
/// slow/adaptive hash instead.
///
/// Used identically for both `users.password_hash`/`password_salt` and
/// `users.pin_hash`/`pin_salt` — a PIN is just a short password for
/// this purpose, same algorithm, same salt length.
class PasswordHasher {
  PasswordHasher._();

  static final Random _random = Random.secure();

  /// Generates a fresh random salt, base64-encoded for storage as TEXT.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hashes [plainText] (a password or a 4-digit PIN) with [salt].
  /// Deterministic for the same input pair — call again with the stored
  /// salt to verify a later attempt.
  static String hash(String plainText, String salt) {
    final bytes = utf8.encode('$salt:$plainText');
    return sha256.convert(bytes).toString();
  }

  /// Constant-time-ish comparison: hashes [plainText] with [salt] and
  /// compares against [expectedHash]. Using a plain `==` on hex strings
  /// here is a normal, safe pattern for local on-device verification
  /// (not a network-facing API where timing side-channels matter).
  static bool verify({required String plainText, required String salt, required String expectedHash}) {
    return hash(plainText, salt) == expectedHash;
  }
}
