/// Date range filters for Riwayat. Per PRD: "Hari Ini, Kemarin, Hari
/// Sebelumnya, Custom Date plus relevant filters" — Hari Ini/Kemarin/
/// Custom are PRD-specified; Semua and Bulan Ini are practical additions
/// under PRD's "plus relevant filters" allowance (not from the React
/// reference, which isn't the source of truth here — see
/// [[mamam-kasir-flutter]] notes on why the reference's recycle-bin
/// pattern was rejected while filter tabs were judged in-spirit-of-PRD).
enum HistoryDateFilter { hariIni, kemarin, hariSebelumnya, bulanIni, semua, custom }

extension HistoryDateFilterX on HistoryDateFilter {
  String get label {
    switch (this) {
      case HistoryDateFilter.hariIni:
        return 'Hari Ini';
      case HistoryDateFilter.kemarin:
        return 'Kemarin';
      case HistoryDateFilter.hariSebelumnya:
        return '7 Hari Terakhir';
      case HistoryDateFilter.bulanIni:
        return 'Bulan Ini';
      case HistoryDateFilter.semua:
        return 'Semua';
      case HistoryDateFilter.custom:
        return 'Tanggal Terpilih';
    }
  }
}

enum HistorySortKey { dateDesc, dateAsc, totalDesc, totalAsc }

extension HistorySortKeyX on HistorySortKey {
  String get label {
    switch (this) {
      case HistorySortKey.dateDesc:
        return 'Terbaru Dulu';
      case HistorySortKey.dateAsc:
        return 'Terlama Dulu';
      case HistorySortKey.totalDesc:
        return 'Nominal Tertinggi';
      case HistorySortKey.totalAsc:
        return 'Nominal Terendah';
    }
  }
}

/// Revenue breakdown for one payment method, within the currently active
/// date/order-type filter (but independent of the payment-method filter
/// itself, so the breakdown always shows the full composition).
class PaymentMethodBreakdown {
  final String method;
  final int total;
  final int count;

  const PaymentMethodBreakdown({required this.method, required this.total, required this.count});
}

/// Order-lifecycle status tab (Diproses/Selesai/Dibatalkan), mapped 1:1
/// to [TransactionStatus] — see that enum's doc comment for the
/// business rules (Diproses = not yet paid, editable; Selesai = paid,
/// counted in Dompet/Dashboard/Laporan; Dibatalkan = canceled, excluded
/// from omzet, never editable again).
enum HistoryStatusFilter { diproses, selesai, dibatalkan }

extension HistoryStatusFilterX on HistoryStatusFilter {
  String get label {
    switch (this) {
      case HistoryStatusFilter.diproses:
        return 'Diproses';
      case HistoryStatusFilter.selesai:
        return 'Selesai';
      case HistoryStatusFilter.dibatalkan:
        return 'Dibatalkan';
    }
  }
}
