/// Minimal "who's logged in" marker shown subtly on the dashboard.
/// Real version should come from the auth/session module (docs/06 phase 3).
class SessionUser {
  final String name;
  final String role; // e.g. "Owner", "Manager", "Cashier"

  const SessionUser({required this.name, required this.role});
}

/// Dashboard summary metrics.
///
/// NOTE: per PRD (docs/01) the officially-specified dashboard metrics are
/// only Omzet Hari Ini, Total Pengeluaran Hari Ini, and Laba Kotor Hari Ini
/// (Laba Kotor = Omzet − Pengeluaran, no HPP). `totalPesanan` and
/// `rataRata` are kept here to match the supplied UI mockup exactly, per
/// explicit instruction — flagged as shell-phase placeholders, not PRD-
/// verified figures. Revisit when dashboard feature logic (phase 22) lands.
class DashboardMetrics {
  final int omzetHariIni;
  final int totalPengeluaran;
  final int labaKotor;
  final int totalPesanan;
  final int rataRata;
  final double growthPercent;

  const DashboardMetrics({
    required this.omzetHariIni,
    required this.totalPengeluaran,
    required this.labaKotor,
    required this.totalPesanan,
    required this.rataRata,
    required this.growthPercent,
  });
}

class SalesTrendPoint {
  final DateTime date;
  final int value;
  final bool isWeekend;

  const SalesTrendPoint({required this.date, required this.value, required this.isWeekend});
}

class DashboardSummary {
  final SessionUser user;
  final DashboardMetrics metrics;
  final List<SalesTrendPoint> trend;
  final int unreadNotifications;
  final int pendingApprovals;

  const DashboardSummary({
    required this.user,
    required this.metrics,
    required this.trend,
    required this.unreadNotifications,
    required this.pendingApprovals,
  });
}
