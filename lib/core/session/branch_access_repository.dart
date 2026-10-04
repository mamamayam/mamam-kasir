import '../data/app_database.dart';
import 'app_session.dart';

/// A branch a user is allowed to operate in — just what a picker or the
/// session needs (id + display name).
class AccessibleBranch {
  final String id;
  final String name;

  const AccessibleBranch({required this.id, required this.name});
}

/// The active-branch rule, with no database involved so it can be tested
/// directly:
///
/// - If [preferredBranchId] (e.g. the branch the user was last in) is
///   still one of [accessibleBranchIds], keep it.
/// - Otherwise fall back to the first accessible branch (the list is
///   expected in `sort_order`).
/// - No accessible branches -> null.
///
/// "Still accessible" matters: a branch can be switched off, or a user's
/// access can change, between sessions — a remembered branch must never
/// be trusted just because it was remembered.
String? pickActiveBranchId({
  required List<String> accessibleBranchIds,
  String? preferredBranchId,
}) {
  if (accessibleBranchIds.isEmpty) return null;
  if (preferredBranchId != null && accessibleBranchIds.contains(preferredBranchId)) {
    return preferredBranchId;
  }
  return accessibleBranchIds.first;
}

/// Which branches a user may operate in, per the PRD's "Branch-scoped
/// operational data for Manager" (docs/handoff/01_PRD.md, Access).
///
/// - Owner: every ACTIVE branch. No `user_branch_access` rows needed —
///   Owner is unrestricted.
/// - Manager / Staff: only branches they have a `user_branch_access`
///   row for, and only while that branch is active. No rows = no
///   branches (fail closed) — the v13 migration and
///   UserManagementRepository.createUser exist precisely so real
///   accounts are never left with none by accident.
///
/// Lives next to the session because the session is what consumes it
/// (AppSessionController resolves the active branch at login/restore).
class BranchAccessRepository {
  Future<List<AccessibleBranch>> accessibleBranches({
    required String userId,
    required AppRole role,
  }) async {
    final db = await AppDatabase.instance.database;

    final List<Map<String, Object?>> rows;
    if (role == AppRole.owner) {
      rows = await db.rawQuery('''
        SELECT id, name FROM branches
        WHERE is_active = 1
        ORDER BY sort_order ASC, name ASC
      ''');
    } else {
      rows = await db.rawQuery('''
        SELECT branches.id AS id, branches.name AS name
        FROM branches
        JOIN user_branch_access ON user_branch_access.branch_id = branches.id
        WHERE user_branch_access.user_id = ? AND branches.is_active = 1
        ORDER BY branches.sort_order ASC, branches.name ASC
      ''', [userId]);
    }

    return rows
        .map((row) => AccessibleBranch(id: row['id'] as String, name: row['name'] as String))
        .toList();
  }

  /// The branch to be active for this user right now, applying
  /// [pickActiveBranchId] to their currently accessible branches.
  Future<String?> resolveActiveBranchId({
    required String userId,
    required AppRole role,
    String? preferredBranchId,
  }) async {
    final accessible = await accessibleBranches(userId: userId, role: role);
    return pickActiveBranchId(
      accessibleBranchIds: accessible.map((b) => b.id).toList(),
      preferredBranchId: preferredBranchId,
    );
  }
}
