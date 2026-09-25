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
    // The 3-day PIN-expiry -> forced password re-login rule
    // (PinAuthRepository.requiresPasswordReentry) and true auto-lock are
    // A3's job to wire in here — for this pass, routing is just: no
    // saved session -> Login (username+password); saved session but no
    // PIN yet for that user -> Set PIN; saved session + PIN already set
    // for that user -> PIN lock screen. "Second-device logout"
    // enforcement (AGENTS.md's "1 user = 1 active device") is Tahap E,
    // out of scope here per the task brief.
    final splashDelay = Future.delayed(const Duration(milliseconds: 900));

    final sessionController = ref.read(appSessionProvider.notifier);
    await sessionController.restore();
    final session = ref.read(appSessionProvider);
    final hasPinSet = session.isLoggedIn
        ? await ref.read(pinAuthRepositoryProvider).hasPinSet(session.userId!)
        : false;

    await splashDelay;
    if (!mounted) return;

    final Widget destination;
    if (!session.isLoggedIn) {
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
