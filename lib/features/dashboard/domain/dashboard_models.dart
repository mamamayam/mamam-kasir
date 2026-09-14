/// "Who's logged in" marker shown subtly on the dashboard. `name`/`role`
/// are null until a real Auth/Staff module exists (docs/06 phase 3) —
/// there is no staff/session table to read from yet, so this stays
/// unset rather than showing an invented name. [SessionMarker] hides
/// itself when both are null instead of rendering "null • null".
class SessionUser {
  final String? name;
  final String? role; // e.g. "Owner", "Manager", "Cashier"

  const SessionUser({this.name, this.role});
}

/// Dashboard summary metrics — all computed from real `transactions` /
/// `cash_movements` rows (see DashboardRepository), not placeholders.
///
/// Per PRD (docs/01) the officially-specified metrics are Omzet Hari
/// Ini, Total Pengeluaran Hari Ini, and Laba Kotor Hari Ini (Laba Kotor
/// = Omzet − Pengeluaran, no HPP). `totalPesanan` and `rataRata` are
/// additional figures kept to match the supplied UI mockup — not
/// PRD-specified, but computed from the same real transaction data
/// (COUNT and AVG respectively), not invented numbers.
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
