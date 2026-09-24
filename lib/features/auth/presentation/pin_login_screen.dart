import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pin_keypad.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/pin_auth_state.dart';
import 'login_screen.dart';
import 'pin_auth_controller.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  @override
  Widget build(BuildContext context) {
    // Listen (not just watch) for the exact moment PIN verification
    // succeeds — addDigit's underlying _verify is now async (checks the
    // real stored PIN via AppSessionController.verifyPin), so we can no
    // longer just read state synchronously right after calling addDigit
    // like the old shell-demo version did; that would race the async
    // check and never see the success. A successful verify leaves
    // enteredDigits at full length with no error/lock (only a failed
    // verify clears enteredDigits back to '') — that combination is
    // unambiguous, so we only navigate on the transition into it to
    // avoid re-navigating on every rebuild.
    ref.listen<PinAuthState>(pinAuthControllerProvider, (previous, next) {
      final succeeded = next.enteredDigits.length == PinAuthState.pinLength && !next.isError && !next.isLocked;
      final justSucceeded = succeeded && previous?.enteredDigits != next.enteredDigits;

      if (justSucceeded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    });

    final state = ref.watch(pinAuthControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Masukkan PIN',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                state.isLocked
                    ? 'Akun terkunci — terlalu banyak percobaan salah'
                    : state.isError
                        ? 'PIN salah, coba lagi'
                        : 'Masukkan 4 digit PIN kamu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: state.isError || state.isLocked ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              AppPinDots(length: PinAuthState.pinLength, filledCount: state.enteredDigits.length, isError: state.isError),
              const Spacer(flex: 2),
              AppPinKeypad(
                disabled: state.isLocked,
                onDigit: (d) => ref.read(pinAuthControllerProvider.notifier).addDigit(d),
                onBackspace: () => ref.read(pinAuthControllerProvider.notifier).backspace(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Login dengan akun lain',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

