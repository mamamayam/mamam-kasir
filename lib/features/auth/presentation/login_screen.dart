import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/auth_repository.dart';
import '../data/pin_auth_repository.dart';
import 'set_pin_screen.dart';
import 'pin_login_screen.dart';

/// Username + password login. Reached from splash (first-ever login on
/// this device) or from PIN screen's "Login dengan akun lain".
///
/// Credentials are checked against the real `users` table via
/// [AuthRepository] (Tahap A/A1 — previously an in-memory hardcoded
/// list, see [[mamam-kasir-flutter]] notes). Swapping to a future real
/// backend later should only require changing what
/// [AuthRepository.verifyCredentials] does internally, not this
/// screen's structure.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Username dan password wajib diisi');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    // A successful call here also clears any PIN lockout for this user
    // (see AuthRepository.verifyCredentials) — re-login with password is
    // this app's only PIN-unlock mechanism, per explicit decision.
    final authenticated = await _authRepository.verifyCredentials(username, password);
    if (!mounted) return;

    if (authenticated == null) {
      setState(() {
        _isSubmitting = false;
        _errorText = 'Username atau password salah';
      });
      return;
    }

    await ref.read(appSessionProvider.notifier).login(
          userId: authenticated.id,
          username: authenticated.username,
          role: authenticated.role,
        );
    if (!mounted) return;

    final hasPinAlready = await ref.read(pinAuthRepositoryProvider).hasPinSet(authenticated.id);
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => hasPinAlready ? const PinLoginScreen() : const SetPinScreen(),
      ),
      (route) => false,
    );
  }

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lupa Password'),
        content: const Text(
          'Hubungi Owner untuk reset password akun kamu. Owner dapat mengatur ulang '
          'lewat akun Supabase yang sama dengan Mamam Global.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Masuk ke Mamam Kasir',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Masukkan username dan password akun kamu',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              const Text('Username', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: _inputDecoration(hint: 'owner atau staff'),
              ),
              const SizedBox(height: 16),
              const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: _inputDecoration(hint: 'Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(_errorText!, style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _forgotPassword,
                  child: const Text(
                    'Lupa password?',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('Masuk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }
}
