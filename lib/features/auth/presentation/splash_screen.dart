import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'pin_login_screen.dart';

/// Splash screen. Kept intentionally simple per instruction ("splash tetap
/// seperti sekarang") — this is a neutral placeholder implementation since
/// no existing splash design was supplied; swap the branded content below
/// if a specific splash asset/animation already exists elsewhere.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // NOTE: real flow should check session/device-auth state here
    // (see AGENTS.md security rules: PIN 3-day expiry, device auth,
    // second-device logout) before deciding where to route.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
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
