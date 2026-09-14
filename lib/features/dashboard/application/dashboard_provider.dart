import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dashboard_models.dart';
import 'dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());

/// Dashboard page state: metrics + trend, loaded together (same pattern
/// as DompetState) so the page has one loading/error surface instead of
/// juggling separate async providers.
///
/// `user`/`unreadNotifications`/`pendingApprovals` stay at their
/// unset/zero defaults — there is no Staff/Auth module (for `user`) or
/// notifications/approvals table (for the other two) to read from yet.
/// Once those modules exist, this state gains real fields for them
/// instead of the counts being invented here.
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
  return DashboardController(ref.watch(dashboardRepositoryProvider));
});

class DashboardController extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardController(this._repository) : super(const DashboardState()) {
    load();
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
