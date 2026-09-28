import 'package:flutter/material.dart';

import '../core/session/app_lifecycle_guard.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/splash_screen.dart';

/// Global navigator key so [AppLifecycleGuard] can push the auto-lock
/// route from a lifecycle callback, which has no [BuildContext] of its
/// own to work with.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class MamamKasirApp extends StatelessWidget {
  const MamamKasirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleGuard(
      navigatorKey: rootNavigatorKey,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        title: 'Mamam Kasir',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
