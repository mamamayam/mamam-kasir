import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../data/pin_auth_repository.dart';
import 'login_screen.dart';
import 'pin_login_screen.dart';
import 'set_pin_screen.dart';

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
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Auto-lock (30 min backgrounded/screen-off) is handled separately
    // by AppLifecycleGuard, which reacts to resume events directly
    // rather than routing through here — this method only covers the
    // cold-start path (app was fully closed/killed, not just
    // backgrounded). The 3-day PIN-expiry -> forced password re-login
    // rule applies on cold start too, via requiresPasswordReentry below.
    // "Second-device logout" enforcement (AGENTS.md's "1 user = 1 active
    // device") is Tahap E, out of scope here per the task brief.
    final splashDelay = Future.delayed(const Duration(milliseconds: 900));

    final sessionController = ref.read(appSessionProvider.notifier);
    await sessionController.restore();
    final session = ref.read(appSessionProvider);

    bool hasPinSet = false;
    bool requiresPassword = false;
    if (session.isLoggedIn) {
      final pinRepo = ref.read(pinAuthRepositoryProvider);
      hasPinSet = await pinRepo.hasPinSet(session.userId!);
      if (hasPinSet) {
        requiresPassword = await pinRepo.requiresPasswordReentry(session.userId!);
      }
    }

    await splashDelay;
    if (!mounted) return;

    final Widget destination;
    if (!session.isLoggedIn || requiresPassword) {
      // requiresPassword routes here too even though a session exists —
      // AGENTS.md's 3-day rule forces a full username+password login,
      // not just re-showing the PIN screen. The session itself (and the
      // PIN, once re-entered) is left untouched; only the route changes.
      destination = const LoginScreen();
    } else if (!hasPinSet) {
      destination = const SetPinScreen();
    } else {
      destination = const PinLoginScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: Center(
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
          ],
        ),
      ),
    );
  }
}
