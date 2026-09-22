import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/pin_auth_state.dart';
import '../domain/hrd_seed_data.dart';

enum HrdPinResult { success, wrong, locked }

/// Who (if anyone) is currently viewing personal pay data on the shared
/// device.
///
/// This is the ONLY source of "who am I" after a PIN succeeds — there is
/// deliberately no way (dropdown, navigation, anything) to switch to
/// another employee's data inside a session. Every new session starts
/// again at "Pilih Nama".
class HrdStaffSessionState {
  final String? employeeId;

  /// Consecutive wrong PINs per employee. Kept OUTSIDE the session so
  /// backing out of the module doesn't reset the lockout.
  final Map<String, int> failedAttempts;

  const HrdStaffSessionState({this.employeeId, this.failedAttempts = const {}});

  bool get isAuthed => employeeId != null;

  int attemptsFor(String employeeId) => failedAttempts[employeeId] ?? 0;

  /// AGENTS.md: 5 wrong PIN attempts locks the account.
  bool isLocked(String employeeId) => attemptsFor(employeeId) >= PinAuthState.maxAttempts;
}

final hrdStaffSessionProvider =
    StateNotifierProvider<HrdStaffSessionController, HrdStaffSessionState>((ref) => HrdStaffSessionController());

class HrdStaffSessionController extends StateNotifier<HrdStaffSessionState> {
  HrdStaffSessionController() : super(const HrdStaffSessionState());

  /// PLACEHOLDER verification against dummy PINs. Never expose the
  /// expected PIN — the result is only success / wrong / locked.
  HrdPinResult verifyPin(String employeeId, String pin) {
    if (state.isLocked(employeeId)) return HrdPinResult.locked;

    final expected = kHrdPlaceholderStaffPins[employeeId];
    if (expected != null && pin == expected) {
      final cleared = {...state.failedAttempts}..remove(employeeId);
      state = HrdStaffSessionState(employeeId: employeeId, failedAttempts: cleared);
      return HrdPinResult.success;
    }

    final attempts = state.attemptsFor(employeeId) + 1;
    state = HrdStaffSessionState(failedAttempts: {...state.failedAttempts, employeeId: attempts});
    return attempts >= PinAuthState.maxAttempts ? HrdPinResult.locked : HrdPinResult.wrong;
  }

  void logout() => state = HrdStaffSessionState(failedAttempts: state.failedAttempts);
}
