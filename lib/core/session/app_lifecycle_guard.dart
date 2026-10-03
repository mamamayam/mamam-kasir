import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_session_provider.dart';
import '../audit/audit_event_type.dart';
import '../audit/audit_providers.dart';
import '../utils/app_clock.dart';
import '../../features/auth/presentation/pin_auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pin_login_screen.dart';

const _kPrefsBackgroundedAtKey = 'app_backgrounded_at';

/// How long the app must have been backgrounded/screen-off before
/// resuming should trigger an auto-lock. Extracted as a top-level
/// constant (rather than buried in a class) so tests can reference the
/// exact same value the app uses, instead of hardcoding "30 minutes" a
/// second time and risking the two silently drifting apart.
const kAutoLockThreshold = Duration(minutes: 30);

/// Pure decision function, no Flutter/widget/DB dependency — given when
/// the app was backgrounded and what time it is now, should resuming
/// trigger an auto-lock? Extracted out of [_AppLifecycleGuardState] so
/// this one piece of actual logic (everything else in that class is
/// Flutter lifecycle plumbing) can be unit-tested directly without a
/// WidgetTester.
bool shouldAutoLock({required DateTime backgroundedAt, required DateTime now, Duration threshold = kAutoLockThreshold}) {
  return now.difference(backgroundedAt) >= threshold;
}

/// A3's auto-lock: 30 minutes of the app being backgrounded or the
/// screen being off (both surface as [AppLifecycleState.paused] in
/// Flutter — see [[mamam-kasir-flutter]] notes on this being a
/// deliberate simplification, NOT per-tap/scroll activity tracking)
/// locks the app back to the PIN screen.
///
/// Wrap the app's `MaterialApp` (or a widget just inside it, with access
/// to its [Navigator] via [navigatorKey]) with this. Cart state and any
/// other provider state is untouched — this only pushes a new route on
/// top of the existing Navigator stack, it never rebuilds
/// [ProviderScope] or resets the widget tree, which is what makes "cart
/// survives auto-lock" true by construction rather than something that
/// needs its own special-case handling.
///
/// Persists the backgrounded timestamp to shared_preferences (not just
/// an in-memory field) because Android/iOS can fully kill the process
/// while it's backgrounded for a long time — a plain in-memory
/// timestamp would be lost exactly when it matters most (a long
/// background period is the case auto-lock exists for).
class AppLifecycleGuard extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final AppClock clock;

  const AppLifecycleGuard({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.clock = AppClock.system,
  });

  @override
  ConsumerState<AppLifecycleGuard> createState() => _AppLifecycleGuardState();
}

class _AppLifecycleGuardState extends ConsumerState<AppLifecycleGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // inactive fires briefly during transient interruptions too
        // (e.g. a system dialog, an incoming call) as well as on the
        // way to paused — recording the timestamp on both is harmless
        // (it just gets overwritten by the next lifecycle event) and
        // guarantees we never miss the moment the app actually leaves
        // the foreground.
        _recordBackgroundedNow();
      case AppLifecycleState.resumed:
        _checkForAutoLockOnResume();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _recordBackgroundedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsBackgroundedAtKey, widget.clock.now().toIso8601String());
  }

  Future<void> _checkForAutoLockOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final backgroundedAtRaw = prefs.getString(_kPrefsBackgroundedAtKey);
    // Clear it immediately so a crash/kill between here and the next
    // background event can't leave a stale timestamp lying around that
    // would incorrectly trigger a lock on some unrelated future resume.
    await prefs.remove(_kPrefsBackgroundedAtKey);
    if (backgroundedAtRaw == null) return;

    final backgroundedAt = DateTime.tryParse(backgroundedAtRaw);
    if (backgroundedAt == null) return;

    final now = widget.clock.now();
    if (!shouldAutoLock(backgroundedAt: backgroundedAt, now: now)) return;

    final session = ref.read(appSessionProvider);
    if (!session.isLoggedIn) return; // Nothing to lock — already at Login.

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    // Avoid stacking a second lock screen on top of one that's already
    // showing — e.g. two resume events firing close together, or the
    // user backgrounded the app FROM PinLoginScreen/LoginScreen itself.
    // Flutter's Navigator doesn't expose "what's the top route's widget
    // type" synchronously without a RouteObserver, and adding one just
    // for this single check felt like more surface area than needed —
    // so PinLoginScreen/LoginScreen set [isLockScreenShowing] themselves
    // in initState/dispose (see the bottom of this file) as the simplest
    // correct signal.
    if (isLockScreenShowing) return;

    final requiresPassword = await ref.read(pinAuthRepositoryProvider).requiresPasswordReentry(session.userId!);

    // Recorded HERE, after every early-return guard above has passed
    // (elapsed time reached the threshold, someone is logged in, and no
    // lock screen is already showing) — so the audit log only ever
    // records an auto-lock that actually fired, never one that was
    // considered and skipped.
    await ref.read(auditRepositoryProvider).record(
          eventType: AuditEventType.autoLock,
          actorUserId: session.userId,
        );

    navigator.push(
      MaterialPageRoute(
        builder: (_) => requiresPassword ? const LoginScreen() : const PinLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Set by [PinLoginScreen] and [LoginScreen] themselves (initState/
/// dispose) so [AppLifecycleGuard] can tell whether one of them is
/// already the top route before pushing another — see the comment at
/// its one call site above for why this exists instead of a
/// RouteObserver-based check. A plain top-level bool rather than a
/// provider because it's pure "is a lock screen currently mounted"
/// bookkeeping with no reason to trigger a rebuild anywhere; nothing
/// ever watches it.
bool isLockScreenShowing = false;
