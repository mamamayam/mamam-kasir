import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pin_keypad.dart';
import '../data/pin_auth_repository.dart';
import 'pin_auth_controller.dart';
import '../domain/pin_auth_state.dart';

enum _ChangePinStage { currentPin, newPin, confirmNewPin }

/// "Ganti PIN" — reachable from Pengaturan while already logged in.
/// Requires the CURRENT PIN first (proves the person holding the phone
/// actually knows it), then the new PIN twice. Does NOT log the user
/// out at any point, before or after — per AGENTS.md's "PIN change
/// requires no logout" and per [PinAuthRepository.changePin], which
/// this screen is a thin UI wrapper around.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _ChangePinStage _stage = _ChangePinStage.currentPin;
  String _currentPinEntry = '';
  String _newPinFirstEntry = '';
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
    switch (_stage) {
      case _ChangePinStage.currentPin:
        await _verifyCurrentPin();
      case _ChangePinStage.newPin:
        setState(() {
          _newPinFirstEntry = _currentDigits;
          _currentDigits = '';
          _stage = _ChangePinStage.confirmNewPin;
        });
      case _ChangePinStage.confirmNewPin:
        await _confirmAndSave();
    }
  }

  Future<void> _verifyCurrentPin() async {
    final userId = ref.read(appSessionProvider).userId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    final result = await ref.read(pinAuthRepositoryProvider).verifyPin(userId, _currentDigits);
    if (!mounted) return;

    if (result != PinVerifyResult.correct) {
      setState(() {
        _isSaving = false;
        _isError = true;
        _currentDigits = '';
      });
      return;
    }

    setState(() {
      _isSaving = false;
      _currentPinEntry = _currentDigits;
      _currentDigits = '';
      _stage = _ChangePinStage.newPin;
    });
  }

  Future<void> _confirmAndSave() async {
    if (_currentDigits != _newPinFirstEntry) {
      setState(() {
        _isError = true;
        _currentDigits = '';
        _newPinFirstEntry = '';
        _stage = _ChangePinStage.newPin;
      });
      return;
    }

    final userId = ref.read(appSessionProvider).userId;
    if (userId == null) return;

    setState(() => _isSaving = true);
    final success = await ref.read(pinAuthRepositoryProvider).changePin(
          userId,
          currentPin: _currentPinEntry,
          newPin: _currentDigits,
        );
    if (!mounted) return;

    if (!success) {
      // The current PIN was re-checked inside changePin and somehow
      // failed even though _verifyCurrentPin already confirmed it —
      // extremely unlikely (would need the PIN to change mid-flow from
      // another device), but fail safely back to the start rather than
      // silently proceeding.
      setState(() {
        _isSaving = false;
        _isError = true;
        _currentDigits = '';
        _currentPinEntry = '';
        _newPinFirstEntry = '';
        _stage = _ChangePinStage.currentPin;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN berhasil diganti')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_stage) {
      _ChangePinStage.currentPin => ('Masukkan PIN Saat Ini', 'Konfirmasi dulu sebelum membuat PIN baru'),
      _ChangePinStage.newPin => ('Buat PIN Baru', 'Buat 4 digit PIN baru'),
      _ChangePinStage.confirmNewPin => ('Konfirmasi PIN Baru', 'Masukkan ulang PIN baru yang sama'),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Spacer(flex: 2),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.pin_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(
                _isError ? 'PIN salah atau tidak cocok, coba lagi' : subtitle,
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
              AppPinKeypad(disabled: _isSaving, onDigit: _handleDigit, onBackspace: _handleBackspace),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
