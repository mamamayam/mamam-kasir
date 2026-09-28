import '../../../core/session/app_session.dart';

/// A login account as shown/edited on the "Kelola Karyawan" (user
/// management) screen. Deliberately excludes password_hash/
/// password_salt/pin_hash/pin_salt/failed_pin_attempts/locked_at — same
/// principle as [PinUserIdentity] (lib/features/auth/domain/
/// pin_user_identity.dart): this model is what UI code is allowed to
/// hold, never a raw `users` row.
class ManagedUser {
  final String id;
  final String username;
  final String displayName;
  final AppRole role;
  final bool isActive;

  const ManagedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  String get roleLabel => switch (role) {
        AppRole.owner => 'Owner',
        AppRole.manager => 'Manager',
        AppRole.staff => 'Staff',
      };
}
