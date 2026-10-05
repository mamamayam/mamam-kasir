import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'pin_auth_controller.dart';
import 'login_screen.dart';
import 'pin_login_screen.dart';
import 'set_pin_screen.dart';

/// Batas waktu maksimal untuk proses startup (restore session + cek PIN
/// di DB). Kalau lewat dari ini, splash menampilkan error + tombol
/// "Coba lagi" daripada diam selamanya.
const _kStartupTimeout = Duration(seconds: 15);

/// Splash screen. Kept intentionally simple per instruction ("splash tetap
/// seperti sekarang") — this is a neutral placeholder implementation since
/// no existing splash design was supplied; swap the branded content below
/// if a specific splash asset/animation already exists elsewhere.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Pesan error startup, kalau ada. Null = normal (masih loading / sudah
  /// pindah halaman).
  String? _error;

  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  /// Menentukan halaman tujuan berdasarkan session + status PIN.
  ///
  /// Logika routing sama persis dengan versi sebelumnya:
  /// - belum login                        -> LoginScreen
  /// - sudah login, belum punya PIN       -> SetPinScreen
  /// - punya PIN, sudah >3 hari tanpa PIN -> LoginScreen (wajib password)
  /// - selain itu                         -> PinLoginScreen
  Future<Widget> _resolveDestination() async {
    final sessionController = ref.read(appSessionProvider.notifier);
    await sessionController.restore();
    final session = ref.read(appSessionProvider);

    if (!session.isLoggedIn) return const LoginScreen();

    final pinRepo = ref.read(pinAuthRepositoryProvider);
    final hasPinSet = await pinRepo.hasPinSet(session.userId!);
    if (!hasPinSet) return const SetPinScreen();

    final requiresPassword = await pinRepo.requiresPasswordReentry(session.userId!);
    if (requiresPassword) return const LoginScreen();

    return const PinLoginScreen();
  }

  Future<void> _navigateNext() async {
    // Auto-lock (30 min backgrounded/screen-off) is handled separately
    // by AppLifecycleGuard, which reacts to resume events directly
    // rather than routing through here — this method only covers the
    // cold-start path (app was fully closed/killed, not just
    // backgrounded). The 3-day PIN-expiry -> forced password re-login
    // rule applies on cold start too, via requiresPasswordReentry.
    // "Second-device logout" enforcement (AGENTS.md's "1 user = 1 active
    // device") is Tahap E, out of scope here per the task brief.
    final splashDelay = Future.delayed(const Duration(milliseconds: 900));

    final Widget destination;
    try {
      destination = await _resolveDestination().timeout(_kStartupTimeout);
    } catch (error, stackTrace) {
      // Sebelumnya tidak ada try/catch di sini: kalau DB gagal dibuka /
      // di-migrate, atau query PIN error, future ini throw diam-diam dan
      // splash nyangkut selamanya tanpa pesan apa pun.
      debugPrint('[SPLASH] Startup gagal: $error');
      debugPrintStack(stackTrace: stackTrace, label: '[SPLASH] stack');
      if (!mounted) return;
      setState(() => _error = error.toString());
      return;
    }

    await splashDelay;
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _retry() {
    setState(() => _error = null);
    _navigateNext();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mamam Kasir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 28),
                const Text(
                  'Gagal memulai aplikasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  error.length > 300 ? '${error.substring(0, 300)}…' : error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retry,
                  child: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}