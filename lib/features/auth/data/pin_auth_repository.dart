import '../../../core/data/app_database.dart';
import '../../../core/data/password_hasher.dart';
import '../../../core/session/app_session.dart';
import '../../../core/utils/app_clock.dart';
import 'pin_user_identity.dart';

/// Result of a PIN verification attempt.
enum PinVerifyResult {
  /// PIN matched — success. Failed-attempt counter was reset to 0.
  correct,

  /// PIN didn't match, and the account is not (yet) locked. Caller
  /// should show "PIN salah" and let the user try again.
  incorrect,

  /// PIN didn't match, and this attempt was the one that crossed
  /// [PinUserIdentity]'s lock threshold — account is now locked.
  /// Caller should show the locked state immediately, same as
  /// [alreadyLocked].
  justLocked,

  /// Account was already locked before this attempt — the attempt was
  /// rejected without even checking the PIN. Per AGENTS.md, this app's
  /// only unlock path is re-login with username+password (see
  /// AuthRepository.verifyCredentials, which clears the lock) — there is
  /// no "wait N minutes" auto-unlock.
  alreadyLocked,
}

/// Per-user PIN storage, verification, and lockout — the A2 replacement
/// for the old app_session_provider.dart's single device-wide
/// `session_device_pin` key.
///
/// PIN is stored on the same `users` row as the password (pin_hash/
/// pin_salt/failed_pin_attempts/locked_at/last_pin_at — see
/// AppDatabase's v10 migration), not in a separate secure-storage entry
/// keyed by device. This was the two-option decision the task brief
/// asked to make explicit: DB row (chosen) vs. secure storage keyed by
/// user id. DB row was chosen because the lockout counter and
/// last-PIN-at timestamp need to be queried and updated transactionally
/// alongside each other on every attempt, which is far simpler as
/// ordinary SQL UPDATEs than as multiple independent secure-storage
/// read-modify-write calls (secure_storage has no transactions). The
/// PIN hash itself sitting in the same SQLCipher-encrypted database as
/// the password hash is no weaker than secure_storage for this app's
/// threat model — both are OS-protected, on-device, single-database-file
/// storage either way.
///
/// All methods require a `userId` — there is no "verify against
/// whichever PIN" path. This is what makes the PIN per-user rather than
/// per-device: two different users on the same device have two
/// completely independent rows, counters, and lock states.
class PinAuthRepository {
  final AppClock _clock;

  PinAuthRepository({AppClock clock = AppClock.system}) : _clock = clock;

  static const int maxAttempts = 5;
  static const int pinLength = 4;

  /// Loads the lightweight identity + current lock status for the PIN
  /// screen to display. Returns null if the user doesn't exist or was
  /// deactivated — callers should treat that the same as "no session",
  /// routing to Login rather than showing a broken PIN screen.
  Future<PinUserIdentity?> loadIdentity(String userId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final roleRows = await db.rawQuery(
      '''
      SELECT roles.name AS role_name
      FROM user_roles
      JOIN roles ON roles.id = user_roles.role_id
      WHERE user_roles.user_id = ?
      LIMIT 1
      ''',
      [userId],
    );
    if (roleRows.isEmpty) return null;

    final role = AppRole.values.where((r) => r.name == roleRows.first['role_name']).firstOrNull;
    if (role == null) return null;

    return PinUserIdentity(
      userId: row['id'] as String,
      displayName: row['display_name'] as String,
      role: role,
      isLocked: row['locked_at'] != null,
    );
  }

  Future<bool> hasPinSet(String userId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', columns: ['pin_hash'], where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return false;
    return rows.first['pin_hash'] != null;
  }

  /// Sets (or overwrites) a user's PIN — used both by the initial
  /// "buat PIN baru" flow after first login and by "Ganti PIN" (change,
  /// no logout required — AGENTS.md). Also clears any lockout, since
  /// setting a new PIN is itself an authenticated action (only reachable
  /// after a fresh username+password login or from inside a session
  /// that's already unlocked) — there is no scenario where a locked
  /// account should stay locked after its PIN was just legitimately
  /// changed.
  Future<void> setPin(String userId, String pin) async {
    final db = await AppDatabase.instance.database;
    final salt = PasswordHasher.generateSalt();
    await db.update(
      'users',
      {
        'pin_hash': PasswordHasher.hash(pin, salt),
        'pin_salt': salt,
        'failed_pin_attempts': 0,
        'locked_at': null,
        'last_pin_at': _clock.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Verifies [pin] for [userId], updating the persistent lockout
  /// counter as a side effect. This persists to the DB on every call —
  /// unlike the old autoDispose-provider-held `failedAttempts`, this
  /// survives app kill/restart and a fresh PinLoginScreen instance,
  /// because it's never held only in memory.
  Future<PinVerifyResult> verifyPin(String userId, String pin) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'users',
      columns: ['pin_hash', 'pin_salt', 'failed_pin_attempts', 'locked_at'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return PinVerifyResult.incorrect;

    final row = rows.first;
    if (row['locked_at'] != null) return PinVerifyResult.alreadyLocked;

    final pinHash = row['pin_hash'] as String?;
    final pinSalt = row['pin_salt'] as String?;
    if (pinHash == null || pinSalt == null) return PinVerifyResult.incorrect; // No PIN set yet.

    final isCorrect = PasswordHasher.verify(plainText: pin, salt: pinSalt, expectedHash: pinHash);

    if (isCorrect) {
      await db.update(
        'users',
        {'failed_pin_attempts': 0, 'last_pin_at': _clock.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return PinVerifyResult.correct;
    }

    final attempts = (row['failed_pin_attempts'] as int) + 1;
    final nowLocked = attempts >= maxAttempts;
    await db.update(
      'users',
      {
        'failed_pin_attempts': attempts,
        if (nowLocked) 'locked_at': _clock.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    return nowLocked ? PinVerifyResult.justLocked : PinVerifyResult.incorrect;
  }

  /// Changes an already-logged-in user's PIN — requires the current PIN
  /// to be correct first (does NOT log the user out either before or
  /// after, per AGENTS.md's "PIN change requires no logout"). Returns
  /// false without changing anything if [currentPin] is wrong.
  Future<bool> changePin(String userId, {required String currentPin, required String newPin}) async {
    final result = await verifyPin(userId, currentPin);
    if (result != PinVerifyResult.correct) return false;
    await setPin(userId, newPin);
    return true;
  }

  /// Whether [userId] has gone 3+ days without a successful PIN entry —
  /// AGENTS.md's "3 hari tanpa PIN -> wajib User ID + password" rule.
  /// A user who has never entered a PIN (last_pin_at is null — e.g.
  /// right after being seeded, before ever completing the "set PIN"
  /// flow) is NOT treated as over the threshold here; that case is
  /// naturally already routed to SetPinScreen by hasPinSet, not this
  /// check. Full wiring into splash/resume is A3's job — this method
  /// exists now so A3 doesn't need to touch PinAuthRepository again.
  Future<bool> requiresPasswordReentry(String userId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', columns: ['last_pin_at'], where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return false;

    final lastPinAt = rows.first['last_pin_at'] as String?;
    if (lastPinAt == null) return false;

    final elapsed = _clock.now().difference(DateTime.parse(lastPinAt));
    return elapsed > const Duration(days: 3);
  }
}
