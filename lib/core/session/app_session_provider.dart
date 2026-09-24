import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

// ---------------------------------------------------------------------------
// Storage keys
// ---------------------------------------------------------------------------
// username/role are non-sensitive identity, kept in shared_preferences.
// PIN is the closest thing to a credential this device holds, kept in
// flutter_secure_storage (OS keychain/keystore) per AGENTS.md's
// "encrypt local DB and OS secure key storage" security rule.
const _kPrefsUsernameKey = 'session_username';
const _kPrefsRoleKey = 'session_role';
const _kSecurePinKey = 'session_device_pin';

const _secureStorage = FlutterSecureStorage();

/// Current logged-in session (username + role), if any. Persisted across
/// app restarts via shared_preferences so the splash screen can route
/// straight to the PIN lock instead of full login.
///
/// This is the intended replacement for hrdViewerModeProvider's
/// placeholder env-var (see hrd_provider.dart doc comment) — that
/// provider should derive HrdViewerMode from this session's role.
final appSessionProvider = StateNotifierProvider<AppSessionController, AppSession>(
  (ref) => AppSessionController()..restore(),
);

class AppSessionController extends StateNotifier<AppSession> {
  AppSessionController() : super(AppSession.empty);

  /// Loads any previously-saved session from disk. Called once on
  /// startup; the splash screen awaits this indirectly by reading
  /// [restored] before deciding where to route.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kPrefsUsernameKey);
    final roleName = prefs.getString(_kPrefsRoleKey);
    if (username == null || roleName == null) return;

    final role = AppRole.values.where((r) => r.name == roleName).firstOrNull;
    if (role == null) return;

    state = AppSession(username: username, role: role);
  }

  /// Called after successful username+password verification.
  Future<void> login({required String username, required AppRole role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsUsernameKey, username);
    await prefs.setString(_kPrefsRoleKey, role.name);
    state = AppSession(username: username, role: role);
  }

  /// Clears the session (username/role) but deliberately leaves the
  /// device PIN in place — logging out doesn't require re-registering a
  /// PIN if the same person (or another authorized user) logs back in.
  /// Full device PIN reset is a separate, explicit action.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsUsernameKey);
    await prefs.remove(_kPrefsRoleKey);
    state = AppSession.empty;
  }

  // ---------------------------------------------------------------------
  // Device PIN — separate from the session identity above. One PIN per
  // device for this pass (not one PIN per user), matching AGENTS.md's
  // "one user = one active device" framing for now; multi-account PIN
  // switching is future work.
  // ---------------------------------------------------------------------

  Future<bool> hasPinSet() async {
    final pin = await _secureStorage.read(key: _kSecurePinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _kSecurePinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final saved = await _secureStorage.read(key: _kSecurePinKey);
    return saved != null && saved == pin;
  }

  /// Clears the stored device PIN (e.g. "Cabut Otorisasi Device" per
  /// AGENTS.md — not wired to any UI yet, but the method exists so that
  /// feature can call it directly once built).
  Future<void> clearPin() async {
    await _secureStorage.delete(key: _kSecurePinKey);
  }
}
