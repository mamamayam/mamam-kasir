import '../domain/laporan_models.dart';

/// STATIC DUMMY DATA for the Laporan placeholder — same "renders the full
/// designed UI with in-memory fake numbers, not wired to POS/DB" approach
/// as the Pelanggan feature (see pelanggan_dummy_data.dart).
///
/// [LaporanRepository] (laporan_repository.dart) already has real,
/// working queries against `transactions` / `cash_expenses` — but those
/// tables are owned by other features (POS / Arus Kas), and pushing
/// LaporanScreen straight to that repository rendered blank in testing
/// (just the iOS header, no body — most likely a build-time exception
/// while assembling the report body, though the exact line wasn't
/// isolated). Routing through dummy data here instead sidesteps that
/// cross-feature DB read entirely so the screen — chart, 4 stat cards,
/// transaction list, filter pills — always has something safe to paint.
///
/// Not read from / written to the database, not synced, not affected by
/// real transactions or expenses. Swap `LaporanController.load()` back to
/// calling `LaporanRepository` (untouched, still below) once the real
/// wiring's blank-render bug is found and fixed.
class LaporanDummyData {
  static ReportData pendapatan(DateTime month) => _build(
        base: 180000,
        variance: 145000,
        daysInMonth: _daysInMonth(month),
        transactionCount: 128,
        rows: _pendapatanRows,
      );

  static ReportData pengeluaran(DateTime month) => _build(
        base: 95000,
        variance: 80000,
        daysInMonth: _daysInMonth(month),
        transactionCount: 42,
        rows: _pengeluaranRows,
      );

  static int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  /// Deterministic (no randomness, so the chart looks the same every
  /// load instead of jittering on every rebuild) pseudo-daily trend —
  /// close enough to a real sales/expense curve to preview the chart,
  /// stat cards, and averages together without a data source.
  static ReportData _build({
    required int base,
    required int variance,
    required int daysInMonth,
    required int transactionCount,
    required List<ReportRow> rows,
  }) {
    final trend = [
      for (var day = 1; day <= daysInMonth; day++) ReportTrendPoint(day: day, value: base + ((day * 37) % variance)),
    ];
    final totalValue = trend.fold<int>(0, (sum, p) => sum + p.value);

    return ReportData(
      totalValue: totalValue,
      transactionCount: transactionCount,
      averagePerTransaction: transactionCount == 0 ? 0 : (totalValue / transactionCount).round(),
      averagePerDay: daysInMonth == 0 ? 0 : (totalValue / daysInMonth).round(),
      trend: trend,
      rows: rows,
    );
  }

  static const List<ReportRow> _pendapatanRows = [
    ReportRow(title: 'Budi Santoso', subtitle: 'TRX-0231 - 05 Sep, 18:20', amount: 68000),
    ReportRow(title: 'Pelanggan Umum', subtitle: 'TRX-0230 - 05 Sep, 15:40', amount: 45000),
    ReportRow(title: 'Siti Aminah', subtitle: 'TRX-0229 - 05 Sep, 12:10', amount: 92000),
    ReportRow(title: 'Andi Wijaya', subtitle: 'TRX-0228 - 04 Sep, 20:05', amount: 105000),
    ReportRow(title: 'Pelanggan Umum', subtitle: 'TRX-0227 - 04 Sep, 17:22', amount: 38000),
    ReportRow(title: 'Dewi Lestari', subtitle: 'TRX-0226 - 04 Sep, 14:32', amount: 68000),
  ];

  static const List<ReportRow> _pengeluaranRows = [
    ReportRow(title: 'Sumber Rejeki', subtitle: 'Bahan Baku - 05 Sep', amount: 320000),
    ReportRow(title: 'PLN', subtitle: 'Listrik - 04 Sep', amount: 250000),
    ReportRow(title: 'Toko Gas Barokah', subtitle: 'Bahan Baku - 03 Sep', amount: 90000),
    ReportRow(title: 'Pengeluaran', subtitle: 'Operasional - 02 Sep', amount: 45000),
    ReportRow(title: 'Warung ATK Jaya', subtitle: 'Perlengkapan - 01 Sep', amount: 60000),
  ];
}
