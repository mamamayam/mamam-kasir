import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pin_keypad.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/pin_auth_repository.dart';
import '../domain/pin_auth_state.dart';

enum _SetPinStage { enter, confirm }

/// Shown once, right after a successful username+password login for a
/// user with no PIN saved yet. Asks for the 4-digit PIN twice (entry +
/// confirmation) before saving it via [PinAuthRepository.setPin] —
/// that PIN is what [PinLoginScreen] checks against on every later
/// login by THIS user (any device — PIN is per-user, not per-device,
/// as of Tahap A/A2; see PinAuthRepository's doc comment).
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  _SetPinStage _stage = _SetPinStage.enter;
  String _firstEntry = '';
  String _currentDigits = '';
  bool _isError = false;
  bool _isSaving = false;

  void _handleDigit(String digit) {
    if (_isSaving) return;
    if (_currentDigits.length >= PinAuthState.pinLength) return;

    setState(() {
      _currentDigits += digit;
      _isError = false;
    });

    if (_currentDigits.length == PinAuthState.pinLength) {
      _onComplete();
    }
  }

  void _handleBackspace() {
    if (_isSaving || _currentDigits.isEmpty) return;
    setState(() {
      _currentDigits = _currentDigits.substring(0, _currentDigits.length - 1);
      _isError = false;
    });
  }

  Future<void> _onComplete() async {
    if (_stage == _SetPinStage.enter) {
      setState(() {
        _firstEntry = _currentDigits;
        _currentDigits = '';
        _stage = _SetPinStage.confirm;
      });
      return;
    }

    // Confirm stage
    if (_currentDigits != _firstEntry) {
      setState(() {
        _isError = true;
        _currentDigits = '';
        _stage = _SetPinStage.enter;
        _firstEntry = '';
      });
      return;
    }

    final userId = ref.read(appSessionProvider).userId;
    if (userId == null) return; // Shouldn't happen — this screen is only reached post-login.

    setState(() => _isSaving = true);
    await ref.read(pinAuthRepositoryProvider).setPin(userId, _currentDigits);
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfirm = _stage == _SetPinStage.confirm;

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
                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(16)),
                child: Icon(
                  isConfirm ? Icons.check_circle_outline_rounded : Icons.pin_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isConfirm ? 'Konfirmasi PIN' : 'Buat PIN Baru',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _isError
                    ? 'PIN tidak cocok, coba lagi'
                    : isConfirm
                        ? 'Masukkan ulang PIN yang sama'
                        : 'Buat 4 digit PIN untuk masuk lebih cepat lain kali',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isError ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              AppPinDots(length: PinAuthState.pinLength, filledCount: _currentDigits.length, isError: _isError),
              const Spacer(flex: 2),
              AppPinKeypad(
                disabled: _isSaving,
                onDigit: _handleDigit,
                onBackspace: _handleBackspace,
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
