import '../../../core/session/app_session.dart';

/// What the PIN screen is allowed to know about the user it's asking to
/// unlock. Deliberately excludes password_hash/password_salt/pin_hash/
/// pin_salt and any other credential field — PinLoginScreen must only
/// ever receive this model, never a raw `users` row.
///
/// Built from a DB row by [PinAuthRepository.loadIdentity] — see that
/// method for how [isLocked] is derived.
class PinUserIdentity {
  final String userId;
  final String displayName;
  final AppRole role;
  final bool isLocked;

  const PinUserIdentity({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.isLocked,
  });

  /// Role label for display — Owner/Manager/Staff, matching the labels
  /// used elsewhere (see dashboard_provider.dart's _toSessionUser).
  String get roleLabel => switch (role) {
        AppRole.owner => 'Owner',
        AppRole.manager => 'Manager',
        AppRole.staff => 'Staff',
      };
}
