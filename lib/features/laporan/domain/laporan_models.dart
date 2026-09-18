/// Domain models for the Laporan (Reports) feature, ported from the
/// approved HTML mockup. Pendapatan and Pengeluaran are the two fully
/// wired report types (real queries against `transactions` /
/// `cash_expenses`); Laba Rugi, Produk, and Customer are selectable in
/// the type picker but have no designed report body yet — selecting them
/// shows a "Segera Hadir" placeholder rather than an invented report.
///
/// Laba Rugi moved here from the swipe-up grid (it used to be its own
/// tile pointing at a generic PlaceholderScreen). It is a report, so it
/// belongs behind the report-type picker with the others; its tile slot
/// in the grid is now Cabang. Only the placeholder was ported — the
/// actual P&L body is deliberately not built yet.
///
/// NOTE when filling Laba Rugi in later: the PRD already pins the
/// formula, do not invent one. Daily gross profit is
/// `Omzet - Pengeluaran` with NO HPP; monthly net profit is
/// `stok opname awal bulan + total expense bulan ini - sisa stok opname
/// bulan ini`. Flipping [isImplemented] is all this enum needs — the
/// screen already routes implemented types to the real body.
enum ReportType {
  pendapatan('Pendapatan'),
  pengeluaran('Pengeluaran'),
  labaRugi('Laba Rugi'),
  produk('Produk'),
  customer('Customer');

  final String label;
  const ReportType(this.label);

  bool get isImplemented => this == ReportType.pendapatan || this == ReportType.pengeluaran;
}

class ReportRow {
  final String title;
  final String subtitle;
  final int amount;

  const ReportRow({required this.title, required this.subtitle, required this.amount});
}

class ReportTrendPoint {
  final int day;
  final int value;

  const ReportTrendPoint({required this.day, required this.value});
}

/// Full report payload for one (type, month) combination — mirrors the
/// mockup's chart + 4 stat cards + transaction list layout for both
/// Pendapatan and Pengeluaran, since they share the exact same shape
/// (only the underlying query and labels differ).
class ReportData {
  final int totalValue;
  final int transactionCount;
  final int averagePerTransaction;
  final int averagePerDay;
  final List<ReportTrendPoint> trend;
  final List<ReportRow> rows;

  const ReportData({
    required this.totalValue,
    required this.transactionCount,
    required this.averagePerTransaction,
    required this.averagePerDay,
    required this.trend,
    required this.rows,
  });

  factory ReportData.empty() => const ReportData(
        totalValue: 0,
        transactionCount: 0,
        averagePerTransaction: 0,
        averagePerDay: 0,
        trend: [],
        rows: [],
      );
}
