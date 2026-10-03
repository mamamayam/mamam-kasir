/// App-level access role — who is logged in and what they're allowed to
/// see. This is deliberately separate from [HrdRole] (payroll job
/// position, e.g. "Manajer"/"Kasir" — see hrd_seed_data.dart), which is
/// unrelated to app access.
///
/// Tahap A: extended from the original 2-role pass (owner/staff) to 3 —
/// Owner, Manager, Staff — per explicit decision: these 3 are
/// permission-scoping labels only, not a deeper "job role" concept.
/// "Staff" stays the umbrella term for anyone who isn't Owner or
/// Manager (kurir, waitress, kasir, etc.) — the PRD's "Cashier" term is
/// used only internally for `roles.name` storage compatibility
/// reasoning in comments, never as this enum's value or as user-facing
/// copy. Multiple roles per user and full custom-role UI remain
/// deferred (DB schema supports it — see app_database.dart's `roles`
/// table — application logic still assumes one role per user).
///
/// A previously-saved session with the old 2-role build's `staff` value
/// still parses safely here (`staff` remains a valid enum name), so no
/// migration is needed for that stored value specifically — see
/// AppSessionController.restore.
enum AppRole { owner, manager, staff }

/// Who is currently logged into this device, if anyone.
///
/// This is the single source of truth for "who am I" at the app level —
/// [hrdViewerModeProvider] and any future per-tile permission check
/// should derive from this rather than keeping their own copy.
///
/// `userId` was added in Tahap A/A1 (previously session identity was
/// username+role only) — A2's per-user PIN storage needs a stable,
/// rename-proof key, and `users.id` (not `username`, which is editable)
/// is that key. A session restored from a pre-A1 save (username+role
/// only, no id persisted) will have `userId == null`; see
/// AppSessionController.restore for how that's handled.
class AppSession {
  final String? userId;
  final String? username;
  final AppRole? role;

  /// The branch this session is operating in (`branches.id`), or null if
  /// the user currently has no accessible branch. Resolved by
  /// AppSessionController at login/restore from [BranchAccessRepository]
  /// — Owner: any active branch; Manager/Staff: only branches granted in
  /// `user_branch_access`.
  ///
  /// Deliberately NOT part of [isLoggedIn]: an account with no branch
  /// can still sign in (it just has nowhere to operate yet). What
  /// operational writes should do with a null branch is a Tahap B
  /// decision — do not assume non-null in code that needs one.
  final String? branchId;

  const AppSession({this.userId, this.username, this.role, this.branchId});

  bool get isLoggedIn => userId != null && username != null && role != null;

  /// Note: passing null for a field keeps the current value (`??`), so
  /// this cannot CLEAR [branchId]; to drop it, construct a new
  /// [AppSession] directly (that is what the controller does).
  AppSession copyWith({String? userId, String? username, AppRole? role, String? branchId}) {
    return AppSession(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
    );
  }

  static const empty = AppSession();
}
