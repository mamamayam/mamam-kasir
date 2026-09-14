/// Domain models for the Laporan (Reports) feature, ported from the
/// approved HTML mockup. Pendapatan and Pengeluaran are the two fully
/// wired report types (real queries against `transactions` /
/// `cash_movements`); Laba, Produk, and Customer remain selectable in
/// the type picker (matching the mockup) but have no designed report
/// body yet — selecting them shows a "Segera Hadir" placeholder rather
/// than an invented report.
enum ReportType {
  pendapatan('Pendapatan'),
  pengeluaran('Pengeluaran'),
  laba('Laba'),
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
