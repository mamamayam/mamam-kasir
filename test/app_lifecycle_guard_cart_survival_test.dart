// Widget test: proves cartProvider's state survives an AppLifecycleGuard
// auto-lock trigger. This is the specific DoD requirement "auto-lock 30
// menit (clock injeksi) dan cart tetap utuh" — asserted directly rather
// than just assumed from AppLifecycleGuard's design (it only pushes a
// route, never rebuilds ProviderScope), since a design claim isn't the
// same as a verified one.
//
// Unlike app_database_auth_test.dart/pin_auth_repository_test.dart, this
// test has no SQLCipher dependency (cartProvider is pure in-memory
// Riverpod state), so it should run fine with plain `flutter test` — no
// device/emulator needed. Still flagged as NOT executed in this sandbox
// (no Flutter SDK available at all — see [[mamam-kasir-flutter]] notes).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/session/app_lifecycle_guard.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
import 'package:mamam_kasir/core/session/app_session_provider.dart';
import 'package:mamam_kasir/core/utils/app_clock.dart';
import 'package:mamam_kasir/features/auth/data/pin_auth_repository.dart';
import 'package:mamam_kasir/features/auth/presentation/pin_auth_controller.dart';
import 'package:mamam_kasir/features/pos/application/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avoids any real SQLCipher/database access in this test —
/// requiresPasswordReentry is the only PinAuthRepository method
/// AppLifecycleGuard calls, and this test only needs it to return a
/// fixed answer, not exercise real per-user DB logic (that's covered by
/// pin_auth_repository_test.dart instead, which does need a device).
class _FakeNoDbPinAuthRepository extends PinAuthRepository {
  @override
  Future<bool> requiresPasswordReentry(String userId) async => false;
}

void main() {
  setUp(() {
    // AppSessionController.login/restore and AppLifecycleGuard's
    // background-timestamp tracking both call
    // SharedPreferences.getInstance() — mock it so this test doesn't
    // need a real platform channel.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('cart state survives an auto-lock trigger (30+ min backgrounded)', (tester) async {
    final clock = FakeClock(DateTime(2026, 1, 1, 12, 0, 0));
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinAuthRepositoryProvider.overrideWithValue(_FakeNoDbPinAuthRepository()),
        ],
        child: AppLifecycleGuard(
          navigatorKey: navigatorKey,
          clock: clock,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const _CartTestHarness(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Grab the ProviderContainer this widget tree is actually using, so
    // reads below are guaranteed to see the same cartProvider instance
    // the app would.
    final container = ProviderScope.containerOf(
      navigatorKey.currentContext!,
    );

    // Simulate being logged in — AppLifecycleGuard's auto-lock check
    // bails out early if there's no session (nothing to lock).
    await container.read(appSessionProvider.notifier).login(
          userId: 'test-user-id',
          username: 'owner',
          role: AppRole.owner,
        );

    // Put something distinctive in the cart.
    container.read(cartProvider.notifier).setGuestName('Budi');
    expect(container.read(cartProvider).guestName, 'Budi');

    // Simulate: app backgrounded, 40 minutes pass (over the 30-min
    // threshold), app resumed.
    final widgetsBinding = TestWidgetsFlutterBinding.ensureInitialized();
    widgetsBinding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // pumpAndSettle (not just pump) so _recordBackgroundedNow's async
    // SharedPreferences write actually completes before the clock
    // advances and resume fires — didChangeAppLifecycleState itself is
    // sync and doesn't await that write.
    await tester.pumpAndSettle();

    clock.advance(const Duration(minutes: 40));

    widgetsBinding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Cart must be untouched — same value as before the lock cycle.
    expect(
      container.read(cartProvider).guestName,
      'Budi',
      reason: 'cartProvider state must survive an auto-lock trigger — AppLifecycleGuard should only push a route, never reset ProviderScope',
    );
  });
}

class _CartTestHarness extends StatelessWidget {
  const _CartTestHarness();

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
