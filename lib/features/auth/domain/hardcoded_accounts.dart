import '../../../core/session/app_session.dart';

/// PLACEHOLDER account list for username+password login.
///
/// No Supabase connection exists yet for this pass (Supabase.initialize
/// is not called anywhere — see [[mamam-kasir-flutter]] notes). This is
/// intentionally the ONLY source of truth for login credentials right
/// now; swap for a real Supabase Auth / users-table lookup once the
/// backend phase lands, without changing anything else in the login
/// flow (LoginScreen only depends on [verifyHardcodedCredentials]).
class HardcodedAccount {
  final String username;
  final String password;
  final AppRole role;

  const HardcodedAccount({required this.username, required this.password, required this.role});
}

const List<HardcodedAccount> kHardcodedAccounts = [
  HardcodedAccount(username: 'owner', password: 'owner123', role: AppRole.owner),
  HardcodedAccount(username: 'staff', password: 'staff123', role: AppRole.staff),
];

/// Returns the matching role if the credentials are valid, else null.
/// Username match is case-insensitive; password is exact.
AppRole? verifyHardcodedCredentials(String username, String password) {
  for (final account in kHardcodedAccounts) {
    if (account.username.toLowerCase() == username.trim().toLowerCase() && account.password == password) {
      return account.role;
    }
  }
  return null;
}
