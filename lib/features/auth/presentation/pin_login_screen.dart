import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_lifecycle_guard.dart' show isLockScreenShowing;
import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_item_thumbnail.dart';
import '../../../core/widgets/app_pin_keypad.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/pin_auth_repository.dart';
import '../domain/pin_auth_state.dart';
import '../domain/pin_user_identity.dart';
import 'login_screen.dart';
import 'pin_auth_controller.dart';

/// Asks for a PIN to unlock the app — but for exactly ONE user: the one
/// last logged in on this device (from [appSessionProvider]), never a
/// picker across multiple accounts (per task brief: "layar PIN hanya
/// menampilkan SATU user"; a user-picker is a separate, out-of-scope
/// feature). Shows that user's name/role so whoever's holding the phone
/// knows whose PIN is being asked for (the phone may be shared/passed
/// between people) — see [PinUserIdentity].
///
/// If there is no logged-in session at all, this screen must not render
/// — there's no "anonymous" PIN screen. [_PinLoginScreenState.build]
/// redirects to [LoginScreen] immediately in that case.
class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  Future<PinUserIdentity?>? _identityFuture;
  String? _loadedForUserId;

  @override
  void initState() {
    super.initState();
    // See app_lifecycle_guard.dart's isLockScreenShowing doc comment —
    // lets AppLifecycleGuard avoid pushing a duplicate lock screen on
    // top of this one.
    isLockScreenShowing = true;
  }

  @override
  void dispose() {
    isLockScreenShowing = false;
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// "Lupa PIN?" — password login that ends in a brand-new PIN instead
  /// of asking for the old one (see LoginScreen.resetPinAfterLogin).
  void _goToForgotPin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen(resetPinAfterLogin: true)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(appSessionProvider.select((s) => s.userId));

    if (userId == null) {
      // No session at all — per the doc comment above, this screen must
      // never render "anonymous". Schedule the redirect after this
      // build finishes (can't call Navigator during build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goToLogin();
      });
      return const Scaffold(backgroundColor: AppColors.background, body: SizedBox.shrink());
    }

    // Reload identity if the userId changed (e.g. hot-swapped session in
    // a test, or — defensively — a future flow that reaches this screen
    // for a different user without a full navigator reset).
    if (_loadedForUserId != userId) {
      _loadedForUserId = userId;
      _identityFuture = ref.read(pinAuthRepositoryProvider).loadIdentity(userId);
    }

    return FutureBuilder<PinUserIdentity?>(
      future: _identityFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final identity = snapshot.data;
        if (identity == null) {
          // User row vanished or was deactivated since login — same
          // fail-closed treatment as "no session at all".
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _goToLogin();
          });
          return const Scaffold(backgroundColor: AppColors.background, body: SizedBox.shrink());
        }

        return _PinEntryView(
          identity: identity,
          onLoginOtherAccount: _goToLogin,
          onForgotPin: _goToForgotPin,
        );
      },
    );
  }
}

class _PinEntryView extends ConsumerWidget {
  final PinUserIdentity identity;
  final VoidCallback onLoginOtherAccount;
  final VoidCallback onForgotPin;

  const _PinEntryView({
    required this.identity,
    required this.onLoginOtherAccount,
    required this.onForgotPin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate ONLY when the controller says the PIN was explicitly
    // verified correct (isVerified). Do NOT infer success from the entered
    // digits: "4 digits, no error, not locked" is also exactly the state
    // for the instant between typing the 4th digit and the async check
    // answering, which used to make ANY 4 digits look like a correct PIN.
    ref.listen<PinAuthState>(pinAuthControllerProvider(identity.userId), (previous, next) {
      final justVerified = next.isVerified && !(previous?.isVerified ?? false);
      if (justVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    });

    final state = ref.watch(pinAuthControllerProvider(identity.userId));
    // identity.isLocked reflects the state as of the last load (right
    // when this screen opened); state.isLocked reflects the live
    // controller, which is updated the instant a 5th wrong attempt
    // locks the account without needing a reload. Either being true
    // means "show locked".
    final isLocked = state.isLocked || identity.isLocked;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              AppItemThumbnail(name: identity.displayName, size: 72),
              const SizedBox(height: AppSpacing.md),
              Text(
                identity.displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              AppStatusBadge(identity.roleLabel, AppColors.textSecondary),
              const SizedBox(height: 20),
              Text(
                isLocked
                    ? 'Akun terkunci — terlalu banyak percobaan salah. Ketuk "Lupa PIN?" untuk login dengan password dan membuat PIN baru.'
                    : state.isError
                        ? 'PIN salah, coba lagi'
                        : 'Masukkan 4 digit PIN kamu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: state.isError || isLocked ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              AppPinDots(length: PinAuthState.pinLength, filledCount: state.enteredDigits.length, isError: state.isError),
              const Spacer(flex: 2),
              AppPinKeypad(
                // Also off while the check is running / after success, so
                // extra taps can't start a second verification.
                disabled: isLocked || state.isVerifying || state.isVerified,
                onDigit: (d) => ref.read(pinAuthControllerProvider(identity.userId).notifier).addDigit(d),
                onBackspace: () => ref.read(pinAuthControllerProvider(identity.userId).notifier).backspace(),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: onForgotPin,
                    child: const Text(
                      'Lupa PIN?',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: onLoginOtherAccount,
                    child: const Text(
                      'Bukan kamu? Ganti akun',
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

