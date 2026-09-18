import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pin_keypad.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/pin_auth_state.dart';
import 'pin_auth_controller.dart';

class PinLoginScreen extends ConsumerWidget {
  const PinLoginScreen({super.key});

  void _handleDigit(WidgetRef ref, BuildContext context, String digit) {
    ref.read(pinAuthControllerProvider.notifier).addDigit(digit);

    final state = ref.read(pinAuthControllerProvider);
    if (state.enteredDigits.length == PinAuthState.pinLength && !state.isError) {
      // Successful shell-demo PIN — proceed to dashboard.
      Future.microtask(() {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onDigit: (d) => _handleDigit(ref, context, d),
                onBackspace: () => ref.read(pinAuthControllerProvider.notifier).backspace(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Login-other-account: routes to full User ID + password
                  // login per spec — stub navigation target for shell phase.
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

