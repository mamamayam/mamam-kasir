import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_pin_keypad.dart';
import '../data/pin_auth_repository.dart';
import 'login_screen.dart';
import 'pin_auth_controller.dart';
import '../domain/pin_auth_state.dart';

enum _ChangePinStage { currentPin, newPin, confirmNewPin }

/// "Ganti PIN" — reachable from Pengaturan while already logged in.
/// Requires the CURRENT PIN first (proves the person holding the phone
/// actually knows it), then the new PIN twice. Does NOT log the user
/// out at any point, before or after — per AGENTS.md's "PIN change
/// requires no logout" and per [PinAuthRepository.changePin], which
/// this screen is a thin UI wrapper around.
///
/// If the account is PIN-locked (5 wrong attempts — possibly from
/// earlier attempts elsewhere), EVERY PIN is rejected, even the right
/// one, because a locked account skips the PIN check entirely. This
/// screen therefore checks the lock state up front and says so, and
/// offers "Lupa PIN saat ini?" (password login → brand-new PIN) instead
/// of leaving the user guessing against a wall with no explanation.
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
  String? _errorText;
  bool _isSaving = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  /// Show a locked account as locked from the moment the screen opens,
  /// rather than only after the user has typed a PIN and been rejected.
  Future<void> _loadLockState() async {
    final userId = ref.read(appSessionProvider).userId;
    if (userId == null) return;
    final identity = await ref.read(pinAuthRepositoryProvider).loadIdentity(userId);
    if (!mounted || identity == null) return;
    if (identity.isLocked) setState(() => _isLocked = true);
  }

  void _handleDigit(String digit) {
    if (_isSaving || _isLocked) return;
    if (_currentDigits.length >= PinAuthState.pinLength) return;

    setState(() {
      _currentDigits += digit;
      _errorText = null;
    });

    if (_currentDigits.length == PinAuthState.pinLength) {
      _onComplete();
    }
  }

  void _handleBackspace() {
    if (_isSaving || _isLocked || _currentDigits.isEmpty) return;
    setState(() {
      _currentDigits = _currentDigits.substring(0, _currentDigits.length - 1);
      _errorText = null;
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

    switch (result) {
      case PinVerifyResult.correct:
        break;
      case PinVerifyResult.incorrect:
        setState(() {
          _isSaving = false;
          _errorText = 'PIN saat ini salah, coba lagi';
          _currentDigits = '';
        });
        return;
      case PinVerifyResult.justLocked:
      case PinVerifyResult.alreadyLocked:
        setState(() {
          _isSaving = false;
          _isLocked = true;
          _errorText = null;
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
        _errorText = 'PIN baru tidak cocok, ulangi';
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
        _errorText = 'Gagal mengganti PIN, ulangi dari awal';
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

  /// "Lupa PIN saat ini?" — leaves this screen for a password login that
  /// ends in a NEW PIN (LoginScreen.resetPinAfterLogin). Confirmed first,
  /// since it takes the user out of the app flow they're in.
  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa PIN?'),
        content: const Text('Kamu akan login ulang dengan username dan password, lalu membuat PIN baru.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Lanjut')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen(resetPinAfterLogin: true)),
      (route) => false,
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
                _isLocked
                    ? 'Akun terkunci — terlalu banyak percobaan salah. Ketuk "Lupa PIN saat ini?" untuk login dengan password dan membuat PIN baru.'
                    : (_errorText ?? subtitle),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: (_isLocked || _errorText != null) ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              AppPinDots(
                length: PinAuthState.pinLength,
                filledCount: _currentDigits.length,
                isError: _isLocked || _errorText != null,
              ),
              const Spacer(flex: 2),
              AppPinKeypad(disabled: _isSaving || _isLocked, onDigit: _handleDigit, onBackspace: _handleBackspace),
              // Only relevant while the CURRENT PIN is what's being asked
              // for (or the account is locked) — once past that step the
              // user has proven they know it.
              if (_stage == _ChangePinStage.currentPin || _isLocked)
                TextButton(
                  onPressed: _isSaving ? null : _forgotPin,
                  child: const Text(
                    'Lupa PIN saat ini?',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                )
              else
                const SizedBox(height: 48),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
