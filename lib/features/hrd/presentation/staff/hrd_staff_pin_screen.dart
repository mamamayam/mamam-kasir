import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_pin_keypad.dart';
import '../../../auth/domain/pin_auth_state.dart';
import '../../application/hrd_provider.dart';
import '../../application/hrd_staff_session_provider.dart';
import 'hrd_staff_dashboard_screen.dart';

/// Staff Screen 2 — PIN. Minimal numpad (plain digits, no button chrome —
/// [AppPinKeypad]'s digit buttons already render this way), 4 dot
/// indicators, logout in the bottom-left cell, backspace bottom-right.
/// Wrong PIN shows an error message; the correct PIN is NEVER revealed in
/// any form.
class HrdStaffPinScreen extends ConsumerStatefulWidget {
  final String employeeId;
  const HrdStaffPinScreen({super.key, required this.employeeId});

  @override
  ConsumerState<HrdStaffPinScreen> createState() => _HrdStaffPinScreenState();
}

class _HrdStaffPinScreenState extends ConsumerState<HrdStaffPinScreen> {
  String _digits = '';
  bool _showError = false;

  void _addDigit(String digit) {
    if (_digits.length >= PinAuthState.pinLength) return;
    setState(() {
      _digits += digit;
      _showError = false;
    });
    if (_digits.length == PinAuthState.pinLength) {
      Future.delayed(const Duration(milliseconds: 150), _submit);
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _showError = false;
    });
  }

  void _submit() {
    if (!mounted) return;
    final result = ref.read(hrdStaffSessionProvider.notifier).verifyPin(widget.employeeId, _digits);
    if (result == HrdPinResult.success) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HrdStaffDashboardScreen()));
      return;
    }
    setState(() {
      _digits = '';
      _showError = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);
    final session = ref.watch(hrdStaffSessionProvider);
    final e = state.employeeById(widget.employeeId);
    final locked = session.isLocked(widget.employeeId);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('Masukan PIN', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(e?.name ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              AppPinDots(length: PinAuthState.pinLength, filledCount: _digits.length, isError: _showError || locked),
              const SizedBox(height: 10),
              if (locked)
                const Text('Terlalu banyak percobaan salah. Coba lagi nanti.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.danger))
              else if (_showError)
                const Text('PIN salah. Silakan coba lagi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.danger)),
              const Spacer(),
              AppPinKeypad(
                disabled: locked,
                onDigit: _addDigit,
                onBackspace: _backspace,
                bottomLeft: _LogoutKey(onTap: () => Navigator.of(context).pop()),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft-red logout chip for the PIN keypad's bottom-left cell, matching
/// the mockup's distinct staff-PIN styling (separate from the owner PIN
/// screen's plain backspace icon).
class _LogoutKey extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
        ),
      ),
    );
  }
}
