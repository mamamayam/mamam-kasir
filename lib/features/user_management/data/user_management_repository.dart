import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../../core/data/password_hasher.dart';
import '../../../core/session/app_session.dart';
import '../domain/managed_user.dart';

const _uuid = Uuid();

/// Thrown when an operation would result in more than one active Owner
/// account. Caught by the UI layer to show a specific error message
/// rather than a generic failure.
class MultipleOwnersException implements Exception {
  const MultipleOwnersException();
}

/// Thrown when an operation would deactivate the sole active Owner
/// account, leaving nothing able to reach Owner-only features
/// (including this very screen).
class CannotDeactivateOwnerException implements Exception {
  const CannotDeactivateOwnerException();
}

/// Thrown when a chosen username is already taken by another active
/// account.
class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

/// CRUD for login accounts (`users`/`user_roles`/`roles`), backing the
/// "Kelola Karyawan" (user management) screen. This is a NEW feature
/// built on top of Tahap A's foundation (see [[mamam-kasir-flutter]]
/// notes) — not one of the lettered A1-A5 steps, but depends entirely on
/// their schema (users/roles/user_roles tables from A1, PasswordHasher
/// from A1/A2).
///
/// Enforces "hanya 1 Owner" as a real runtime check (via [hasOwner]),
/// closing the gap A1 deliberately left as seed-construction-only (see
/// A1's `_seedAuthData` doc comment in app_database.dart) — this
/// repository is the first place that gap needed closing for real,
/// since it's the first place a second Owner could actually be created.
///
/// Deletion is soft-delete only (`is_active = 0`) — a deactivated
/// user's row, and anything elsewhere in the app that references their
/// `user_id` (audit trails, transaction `created_by`, etc., once those
/// exist), stays intact. There is no hard-delete path here at all.
class UserManagementRepository {
  Future<List<ManagedUser>> listUsers({bool includeInactive = true}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT users.id, users.username, users.display_name, users.is_active, roles.name AS role_name
      FROM users
      JOIN user_roles ON user_roles.user_id = users.id
      JOIN roles ON roles.id = user_roles.role_id
      ${includeInactive ? '' : 'WHERE users.is_active = 1'}
      ORDER BY users.created_at ASC
    ''');

    return rows
        .map((row) {
          final role = AppRole.values.where((r) => r.name == row['role_name']).firstOrNull;
          if (role == null) return null; // Unknown role name — skip rather than crash the list.
          return ManagedUser(
            id: row['id'] as String,
            username: row['username'] as String,
            displayName: row['display_name'] as String,
            role: role,
            isActive: (row['is_active'] as int) == 1,
          );
        })
        .whereType<ManagedUser>()
        .toList();
  }

  /// Whether an active Owner account currently exists. [excludingUserId]
  /// lets an edit-in-progress check "would this still be true if I
  /// exclude the user I'm currently editing" — otherwise editing the
  /// existing Owner's own row (without changing their role) would
  /// always incorrectly report "an Owner already exists" and block the
  /// edit.
  Future<bool> hasOwner({String? excludingUserId}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt
      FROM user_roles
      JOIN roles ON roles.id = user_roles.role_id
      JOIN users ON users.id = user_roles.user_id
      WHERE roles.name = 'owner' AND users.is_active = 1
      ${excludingUserId != null ? 'AND users.id != ?' : ''}
      ''',
      excludingUserId != null ? [excludingUserId] : [],
    );
    return (rows.first['cnt'] as int) > 0;
  }

  Future<bool> _isUsernameTaken(String username, {String? excludingUserId}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'users',
      where: excludingUserId != null ? 'username = ? COLLATE NOCASE AND id != ?' : 'username = ? COLLATE NOCASE',
      whereArgs: excludingUserId != null ? [username.trim(), excludingUserId] : [username.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Creates a new login account. Throws [MultipleOwnersException] if
  /// [role] is Owner and an active Owner already exists, or
  /// [UsernameTakenException] if [username] is already in use — check
  /// both BEFORE showing a confirmation/saving indicator in the UI where
  /// possible, but this method re-checks regardless so it's safe to call
  /// on its own.
  Future<String> createUser({
    required String username,
    required String password,
    required String displayName,
    required AppRole role,
  }) async {
    if (await _isUsernameTaken(username)) throw const UsernameTakenException();
    if (role == AppRole.owner && await hasOwner()) throw const MultipleOwnersException();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final userId = _uuid.v4();
    final salt = PasswordHasher.generateSalt();

    await db.insert('users', {
      'id': userId,
      'username': username.trim(),
      'display_name': displayName.trim(),
      'password_hash': PasswordHasher.hash(password, salt),
      'password_salt': salt,
      'pin_hash': null,
      'pin_salt': null,
      'failed_pin_attempts': 0,
      'locked_at': null,
      'last_pin_at': null,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    final roleRow = await db.query('roles', where: 'name = ?', whereArgs: [role.name], limit: 1);
    if (roleRow.isEmpty) {
      throw StateError('Role "${role.name}" not found in roles table — this should never happen for a built-in AppRole value.');
    }

    await db.insert('user_roles', {
      'id': _uuid.v4(),
      'user_id': userId,
      'role_id': roleRow.first['id'],
      'created_at': now,
    });

    return userId;
  }

  /// Updates an existing account's username/displayName/role, and
  /// optionally its password (leave [newPassword] null to keep the
  /// current one — this method never requires re-entering a password
  /// just to change a username or role). Same [MultipleOwnersException]/
  /// [UsernameTakenException] guards as [createUser], with the "editing
  /// myself" exclusion described on [hasOwner].
  ///
  /// Deliberately does NOT touch the target user's PIN, lockout state,
  /// or `last_pin_at` — those are [PinAuthRepository]'s territory, kept
  /// separate here the same way [AuthRepository]/[PinAuthRepository]
  /// already keep password and PIN concerns apart from each other.
  Future<void> updateUser({
    required String userId,
    required String username,
    required String displayName,
    required AppRole role,
    String? newPassword,
  }) async {
    if (await _isUsernameTaken(username, excludingUserId: userId)) throw const UsernameTakenException();
    if (role == AppRole.owner && await hasOwner(excludingUserId: userId)) throw const MultipleOwnersException();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();

    final values = <String, Object?>{
      'username': username.trim(),
      'display_name': displayName.trim(),
      'updated_at': now,
    };
    if (newPassword != null && newPassword.isNotEmpty) {
      final salt = PasswordHasher.generateSalt();
      values['password_hash'] = PasswordHasher.hash(newPassword, salt);
      values['password_salt'] = salt;
    }

    await db.update('users', values, where: 'id = ?', whereArgs: [userId]);

    final roleRow = await db.query('roles', where: 'name = ?', whereArgs: [role.name], limit: 1);
    if (roleRow.isEmpty) {
      throw StateError('Role "${role.name}" not found in roles table — this should never happen for a built-in AppRole value.');
    }
    // One role per user for this pass (see AppRole's doc comment) —
    // replace rather than add, so a role change never leaves a stale
    // second row behind.
    await db.delete('user_roles', where: 'user_id = ?', whereArgs: [userId]);
    await db.insert('user_roles', {
      'id': _uuid.v4(),
      'user_id': userId,
      'role_id': roleRow.first['id'],
      'created_at': now,
    });
  }

  /// Soft-deletes (deactivates) an account — see this class's doc
  /// comment on why there is no hard-delete. A deactivated user cannot
  /// log in ([AuthRepository.verifyCredentials] filters on
  /// `is_active = 1`) but their row and history remain.
  ///
  /// Throws [CannotDeactivateOwnerException] if [userId] is the Owner —
  /// deactivating the sole Owner would leave nobody able to reach any
  /// Owner-only feature, including this very screen, so it's blocked
  /// entirely rather than just discouraged.
  Future<void> deactivateUser(String userId) async {
    final db = await AppDatabase.instance.database;

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
    if (roleRows.isNotEmpty && roleRows.first['role_name'] == AppRole.owner.name) {
      throw const CannotDeactivateOwnerException();
    }

    await db.update(
      'users',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Reactivates a previously soft-deleted account. Re-checks the
  /// single-Owner rule too — reactivating an old Owner account while a
  /// different Owner is currently active must be blocked the same as
  /// creating a second one would be.
  Future<void> reactivateUser(String userId, {required AppRole role}) async {
    if (role == AppRole.owner && await hasOwner(excludingUserId: userId)) throw const MultipleOwnersException();

    final db = await AppDatabase.instance.database;
    await db.update(
      'users',
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
