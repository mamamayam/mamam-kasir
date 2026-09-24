import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session.dart';
import '../../../core/session/app_session_provider.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());

/// Dashboard page state: metrics + trend, loaded together (same pattern
/// as DompetState) so the page has one loading/error surface instead of
/// juggling separate async providers.
///
/// `unreadNotifications`/`pendingApprovals` stay at their unset/zero
/// defaults — there is no notifications/approvals table to read from
/// yet (pendingApprovals for the Owner approval sheet is read directly
/// from hrdControllerProvider elsewhere, not through here). `user` is
/// now real — see [DashboardController]'s constructor.
class DashboardState {
  final SessionUser user;
  final DashboardMetrics? metrics;
  final List<SalesTrendPoint> trend;
  final int unreadNotifications;
  final int pendingApprovals;
  final bool isLoading;
  final String? errorMessage;

  const DashboardState({
    this.user = const SessionUser(),
    this.metrics,
    this.trend = const [],
    this.unreadNotifications = 0,
    this.pendingApprovals = 0,
    this.isLoading = true,
    this.errorMessage,
  });

  DashboardState copyWith({
    SessionUser? user,
    DashboardMetrics? metrics,
    List<SalesTrendPoint>? trend,
    int? unreadNotifications,
    int? pendingApprovals,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      user: user ?? this.user,
      metrics: metrics ?? this.metrics,
      trend: trend ?? this.trend,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final dashboardProvider = StateNotifierProvider.autoDispose<DashboardController, DashboardState>((ref) {
  final controller = DashboardController(ref.watch(dashboardRepositoryProvider));

  // Keep DashboardState.user in sync with the real logged-in session
  // (see SessionMarker's doc comment — this is the "real Auth/Staff
  // module" it was waiting on). fireImmediately so the header shows the
  // right role/name on first build, not just after the next login.
  ref.listen<AppSession>(appSessionProvider, (previous, next) {
    controller.setUser(_toSessionUser(next));
  }, fireImmediately: true);

  return controller;
});

SessionUser _toSessionUser(AppSession session) {
  if (!session.isLoggedIn) return const SessionUser();
  final roleLabel = session.role == AppRole.owner ? 'Owner' : 'Staff';
  return SessionUser(name: session.username, role: roleLabel);
}

class DashboardController extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardController(this._repository) : super(const DashboardState()) {
    load();
  }

  void setUser(SessionUser user) {
    state = state.copyWith(user: user);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final metrics = await _repository.getMetrics();
      final trend = await _repository.getSalesTrend();

      state = state.copyWith(
        metrics: metrics,
        trend: trend,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data Dashboard: $e');
    }
  }
}
