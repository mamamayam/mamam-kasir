import '../data/app_database.dart';
import '../session/app_session.dart';
import 'permission_defaults.dart';
import 'permission_key.dart';
import 'permission_mode.dart';

/// Resolves what a role may do for a given [PermissionKey], per the
/// PRD's deny/direct/approval model. This is the single place that
/// question is answered — callers (widgets, future use-cases) call
/// [PermissionService.resolve] or [PermissionService.isAllowed] instead
/// of checking `role == AppRole.owner` themselves, per the task brief's
/// "dipanggil dari use case/service, bukan hanya if (isOwner) di
/// widget."
///
/// Reads from the `permissions` table (role_id, permission_key, mode —
/// see AppDatabase's v10 migration) so "perubahan permission berlaku
/// langsung" (changes apply immediately, no separate cache to
/// invalidate) — every [resolve] call is a fresh query, not a value
/// computed once and held onto.
///
/// [defaultPermissions] (permission_defaults.dart) is the fallback used
/// when the `permissions` table has no row for a given (role, key) pair.
/// A v11 migration seeds the table from that same source, but a device
/// that hasn't upgraded yet (or a (role, key) pair added after that
/// migration ran) still gets correct behavior from the fallback — see
/// permission_defaults.dart's doc comment for why the two never drift
/// apart.
class PermissionService {
  /// Resolves the [PermissionMode] for [role] + [key]. A null [role]
  /// (no session) always resolves to [PermissionMode.deny] — there is
  /// no "logged out but still direct" case.
  Future<PermissionMode> resolve(AppRole? role, PermissionKey key) async {
    if (role == null) return PermissionMode.deny;

    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT permissions.mode
      FROM permissions
      JOIN roles ON roles.id = permissions.role_id
      WHERE roles.name = ? AND permissions.permission_key = ?
      LIMIT 1
      ''',
      [role.name, key.name],
    );

    if (rows.isNotEmpty) {
      final modeName = rows.first['mode'] as String;
      final mode = PermissionMode.values.where((m) => m.name == modeName).firstOrNull;
      if (mode != null) return mode;
      // Unrecognized mode string in the DB (shouldn't happen from this
      // app's own writes) — fail closed to the hardcoded default rather
      // than silently granting access on bad data.
    }

    return defaultPermissions[key]?[role] ?? PermissionMode.deny;
  }

  /// Convenience for the common case of "can this role do this at all
  /// right now" — true only for [PermissionMode.direct]. Callers that
  /// need to distinguish `approval` (e.g. to route into an approval
  /// flow instead of just failing) should call [resolve] directly
  /// rather than this method.
  Future<bool> isAllowed(AppRole? role, PermissionKey key) async {
    return await resolve(role, key) == PermissionMode.direct;
  }
}
