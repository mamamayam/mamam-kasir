import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
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
              _PinDots(state: state),
              const Spacer(flex: 2),
              _Keypad(
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

class _PinDots extends StatelessWidget {
  final PinAuthState state;
  const _PinDots({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(PinAuthState.pinLength, (i) {
        final filled = i < state.enteredDigits.length;
        final color = state.isError
            ? AppColors.danger
            : filled
                ? AppColors.brand
                : AppColors.border;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled || state.isError ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  final bool disabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _Keypad({required this.disabled, required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 72);
              }
              if (key == 'back') {
                return _KeypadButton(
                  disabled: disabled,
                  onTap: onBackspace,
                  child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textSecondary),
                );
              }
              return _KeypadButton(
                disabled: disabled,
                onTap: () => onDigit(key),
                child: Text(
                  key,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;
  final Widget child;

  const _KeypadButton({required this.disabled, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: disabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
