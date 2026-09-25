import '../../../core/data/app_database.dart';
import '../../../core/data/password_hasher.dart';
import '../../../core/session/app_session.dart';

/// Result of a successful username+password lookup — just enough to
/// start a session and route to the PIN flow. Deliberately carries no
/// hash/salt/credential fields (those never leave the repository layer).
class AuthenticatedUser {
  final String id;
  final String username;
  final String displayName;
  final AppRole role;

  const AuthenticatedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });
}

/// DB-backed replacement for the old hardcoded_accounts.dart in-memory
/// list (see [[mamam-kasir-flutter]] notes) — login now looks up the
/// real `users`/`user_roles`/`roles` rows seeded by
/// AppDatabase._seedAuthData in the v10 migration (owner/owner123,
/// manager/manager123, staff/staff123 — same credentials as before,
/// just DB-backed and hashed instead of an in-memory plaintext list).
///
/// LoginScreen depends only on [verifyCredentials] (mirroring the old
/// module-level `verifyHardcodedCredentials` function's role as the
/// single seam that screen touches), so nothing about LoginScreen's
/// structure needed to change for this swap.
class AuthRepository {
  Future<AuthenticatedUser?> verifyCredentials(String username, String password) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'users',
      where: 'username = ? COLLATE NOCASE AND is_active = 1',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final isCorrect = PasswordHasher.verify(
      plainText: password,
      salt: row['password_salt'] as String,
      expectedHash: row['password_hash'] as String,
    );
    if (!isCorrect) return null;

    final roleRows = await db.rawQuery(
      '''
      SELECT roles.name AS role_name
      FROM user_roles
      JOIN roles ON roles.id = user_roles.role_id
      WHERE user_roles.user_id = ?
      LIMIT 1
      ''',
      [row['id']],
    );
    if (roleRows.isEmpty) return null; // No role assigned — cannot log in.

    final roleName = roleRows.first['role_name'] as String;
    final role = AppRole.values.where((r) => r.name == roleName).firstOrNull;
    if (role == null) return null; // Unknown role name — fail closed.

    // A successful username+password login is this app's ONLY unlock
    // mechanism for a PIN-locked account (explicit decision — no
    // "unlock by another user" path, since there's only ever one
    // Owner and PRD doesn't specify a separate unlock flow). Clearing
    // the lockout here, rather than requiring a second explicit action,
    // means "re-login with password" IS the unlock — nothing else
    // needs to remember to call this.
    await db.update(
      'users',
      {'failed_pin_attempts': 0, 'locked_at': null},
      where: 'id = ?',
      whereArgs: [row['id']],
    );

    return AuthenticatedUser(
      id: row['id'] as String,
      username: row['username'] as String,
      displayName: row['display_name'] as String,
      role: role,
    );
  }
}
