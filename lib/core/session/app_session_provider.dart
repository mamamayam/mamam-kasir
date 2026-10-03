import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audit/audit_event_type.dart';
import '../audit/audit_providers.dart';
import '../audit/audit_repository.dart';
import 'app_session.dart';
import 'branch_access_repository.dart';

// ---------------------------------------------------------------------------
// Storage keys
// ---------------------------------------------------------------------------
// username/role/userId are non-sensitive identity, kept in
// shared_preferences. There is no PIN storage in this file anymore —
// see the A2 migration note below.
const _kPrefsUserIdKey = 'session_user_id';
const _kPrefsUsernameKey = 'session_username';
const _kPrefsRoleKey = 'session_role';
const _kPrefsBranchIdKey = 'session_branch_id';

/// Current logged-in session (user id + username + role), if any.
/// Persisted across app restarts via shared_preferences so the splash
/// screen can route straight to the PIN lock instead of full login.
///
/// This is the intended replacement for hrdViewerModeProvider's
/// placeholder env-var (see hrd_provider.dart doc comment) — that
/// provider should derive HrdViewerMode from this session's role.
final branchAccessRepositoryProvider = Provider<BranchAccessRepository>((ref) => BranchAccessRepository());

final appSessionProvider = StateNotifierProvider<AppSessionController, AppSession>(
  (ref) => AppSessionController(
    audit: ref.watch(auditRepositoryProvider),
    branchAccess: ref.watch(branchAccessRepositoryProvider),
  )..restore(),
);

/// Identity-only session controller. PIN storage/verification used to
/// live here as a single device-wide `session_device_pin` secure-storage
/// key — Tahap A/A2 tore that out entirely (per explicit decision: a
/// PIN belongs to a user, not a device; a shared device-wide PIN would
/// let anyone who learns it log in as anyone else, including Owner).
/// PIN is now handled by [PinAuthRepository] (lib/features/auth/data/
/// pin_auth_repository.dart), keyed by userId and stored on each user's
/// own `users` row alongside their password hash — see that class's doc
/// comment for the full reasoning. There is intentionally no PIN-related
/// method left on this controller; callers needing PIN behavior should
/// depend on [PinAuthRepository] directly, using `state.userId` from
/// this session to know which user's PIN to act on.
class AppSessionController extends StateNotifier<AppSession> {
  final AuditRepository _audit;
  final BranchAccessRepository _branchAccess;

  AppSessionController({AuditRepository? audit, BranchAccessRepository? branchAccess})
      : _audit = audit ?? AuditRepository(),
        _branchAccess = branchAccess ?? BranchAccessRepository(),
        super(AppSession.empty);

  /// Works out which branch this user should be operating in, keeping
  /// [preferredBranchId] only if they can still access it (see
  /// [pickActiveBranchId]). A failed lookup yields null rather than an
  /// exception: not being able to read branch access must not stop
  /// someone signing in — same principle as audit logging (see
  /// AuditRepository.record). The cost is a null branch for that
  /// session, which is reported to the debug console.
  Future<String?> _resolveBranch(String userId, AppRole role, String? preferredBranchId) async {
    try {
      return await _branchAccess.resolveActiveBranchId(
        userId: userId,
        role: role,
        preferredBranchId: preferredBranchId,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Gagal menentukan cabang aktif — sesi dilanjutkan tanpa cabang.',
        name: 'session',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistBranch(SharedPreferences prefs, String? branchId) async {
    if (branchId == null) {
      await prefs.remove(_kPrefsBranchIdKey);
    } else {
      await prefs.setString(_kPrefsBranchIdKey, branchId);
    }
  }

  /// Loads any previously-saved session from disk. Called once on
  /// startup; the splash screen awaits this indirectly by reading
  /// [restored] before deciding where to route.
  ///
  /// A session saved before Tahap A/A1 (username+role only, no user id)
  /// will have no stored `session_user_id` — that's treated as "not
  /// logged in" (isLoggedIn requires userId too), which safely routes
  /// back to Login rather than trying to guess an id. This is the only
  /// migration a pre-A1 saved session needs: no separate migration
  /// script, just this fail-closed read.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kPrefsUserIdKey);
    final username = prefs.getString(_kPrefsUsernameKey);
    final roleName = prefs.getString(_kPrefsRoleKey);
    if (userId == null || username == null || roleName == null) return;

    final role = AppRole.values.where((r) => r.name == roleName).firstOrNull;
    if (role == null) return;

    // The remembered branch is re-validated, never trusted: it may have
    // been switched off, or this user's access changed, since last run.
    final branchId = await _resolveBranch(userId, role, prefs.getString(_kPrefsBranchIdKey));
    await _persistBranch(prefs, branchId);

    state = AppSession(userId: userId, username: username, role: role, branchId: branchId);
  }

  /// Called after successful username+password verification.
  Future<void> login({required String userId, required String username, required AppRole role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsUserIdKey, userId);
    await prefs.setString(_kPrefsUsernameKey, username);
    await prefs.setString(_kPrefsRoleKey, role.name);

    // A fresh login starts from the user's default branch. (Deliberately
    // NOT reusing a remembered branch: the remembered one may belong to
    // a different account that was signed in before.)
    final branchId = await _resolveBranch(userId, role, null);
    await _persistBranch(prefs, branchId);

    state = AppSession(userId: userId, username: username, role: role, branchId: branchId);
  }

  /// Switches the active branch, but only to one this user can actually
  /// access. Returns false (and changes nothing) if not signed in or the
  /// branch isn't accessible to them.
  ///
  /// Nothing in the UI calls this yet — there is no branch picker. It
  /// exists so that when one is built, the rule "you can only switch to
  /// a branch you have access to" is already enforced here rather than
  /// re-implemented (or forgotten) in a widget.
  Future<bool> setActiveBranch(String branchId) async {
    final userId = state.userId;
    final role = state.role;
    if (userId == null || role == null) return false;

    final accessible = await _branchAccess.accessibleBranches(userId: userId, role: role);
    if (!accessible.any((b) => b.id == branchId)) return false;

    final prefs = await SharedPreferences.getInstance();
    await _persistBranch(prefs, branchId);
    state = AppSession(userId: userId, username: state.username, role: role, branchId: branchId);
    return true;
  }

  /// Clears the session (identity) but deliberately leaves the user's
  /// PIN in place (now stored per-user in the DB, not touched by this
  /// method at all) — logging out doesn't require re-registering a PIN
  /// if the same person logs back in. Full PIN reset is a separate,
  /// explicit action via PinAuthRepository.
  Future<void> logout() async {
    // Capture BEFORE clearing state — once state is AppSession.empty
    // there is no userId left to attribute the logout to.
    final userIdBeforeLogout = state.userId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsUserIdKey);
    await prefs.remove(_kPrefsUsernameKey);
    await prefs.remove(_kPrefsRoleKey);
    await prefs.remove(_kPrefsBranchIdKey);
    state = AppSession.empty;

    // Only record if there actually was a logged-in user — calling
    // logout() with no session (defensive, shouldn't normally happen)
    // shouldn't write an actor-less "logout" row that never
    // corresponded to a real logout.
    if (userIdBeforeLogout != null) {
      await _audit.record(eventType: AuditEventType.logout, actorUserId: userIdBeforeLogout);
    }
  }
}
