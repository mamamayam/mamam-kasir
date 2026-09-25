import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

// ---------------------------------------------------------------------------
// Storage keys
// ---------------------------------------------------------------------------
// username/role/userId are non-sensitive identity, kept in
// shared_preferences. There is no PIN storage in this file anymore —
// see the A2 migration note below.
const _kPrefsUserIdKey = 'session_user_id';
const _kPrefsUsernameKey = 'session_username';
const _kPrefsRoleKey = 'session_role';

/// Current logged-in session (user id + username + role), if any.
/// Persisted across app restarts via shared_preferences so the splash
/// screen can route straight to the PIN lock instead of full login.
///
/// This is the intended replacement for hrdViewerModeProvider's
/// placeholder env-var (see hrd_provider.dart doc comment) — that
/// provider should derive HrdViewerMode from this session's role.
final appSessionProvider = StateNotifierProvider<AppSessionController, AppSession>(
  (ref) => AppSessionController()..restore(),
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
  AppSessionController() : super(AppSession.empty);

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

    state = AppSession(userId: userId, username: username, role: role);
  }

  /// Called after successful username+password verification.
  Future<void> login({required String userId, required String username, required AppRole role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsUserIdKey, userId);
    await prefs.setString(_kPrefsUsernameKey, username);
    await prefs.setString(_kPrefsRoleKey, role.name);
    state = AppSession(userId: userId, username: username, role: role);
  }

  /// Clears the session (identity) but deliberately leaves the user's
  /// PIN in place (now stored per-user in the DB, not touched by this
  /// method at all) — logging out doesn't require re-registering a PIN
  /// if the same person logs back in. Full PIN reset is a separate,
  /// explicit action via PinAuthRepository.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsUserIdKey);
    await prefs.remove(_kPrefsUsernameKey);
    await prefs.remove(_kPrefsRoleKey);
    state = AppSession.empty;
  }
}
