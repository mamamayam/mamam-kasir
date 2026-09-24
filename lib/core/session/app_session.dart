/// App-level access role — who is logged in and what they're allowed to
/// see. This is deliberately separate from [HrdRole] (payroll job
/// position, e.g. "Manajer"/"Kasir" — see hrd_seed_data.dart), which is
/// unrelated to app access.
///
/// Scope for this pass (see [[mamam-kasir-flutter]] notes): exactly one
/// role per user, Owner or Staff. "Staff" is deliberately the umbrella
/// term for anyone who isn't Owner (future: kurir, waitress, kasir,
/// etc.) — not narrowed to "Cashier". A Manager tier and granular
/// per-tile permission modes (not allowed/direct/approval per AGENTS.md)
/// are explicitly deferred, not implemented here.
enum AppRole { owner, staff }

/// Who is currently logged into this device, if anyone.
///
/// This is the single source of truth for "who am I" at the app level —
/// [hrdViewerModeProvider] and any future per-tile permission check
/// should derive from this rather than keeping their own copy.
class AppSession {
  final String? username;
  final AppRole? role;

  const AppSession({this.username, this.role});

  bool get isLoggedIn => username != null && role != null;

  AppSession copyWith({String? username, AppRole? role}) {
    return AppSession(username: username ?? this.username, role: role ?? this.role);
  }

  static const empty = AppSession();
}
