import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../domain/laporan_models.dart';

/// Reads Pendapatan/Pengeluaran report data for a given month from the
/// same tables the rest of the app writes to — same "compute on read, no
/// separate reports store" approach as DashboardRepository /
/// DompetRepository.
///
/// Sources, and why:
/// - Pendapatan -> `transactions` WHERE status = 'paid'. Canceled rows
///   stay in the table as records but are excluded from omzet (PRD §
///   Transactions), which `status = 'paid'` already handles.
/// - Pengeluaran -> `cash_expenses` WHERE direction = 'pengeluaran'.
///   This is the Arus Kas ledger and the real source of truth for
///   expenses. It deliberately does NOT read `cash_movements` with
///   type = 'expense': that table only mirrors the CASH-funded subset
///   (ArusKasRepository writes a cash_movement only when
///   funding_source = 'cash_location'), so a transfer/QRIS-funded
///   expense would silently never appear in this report.
///
/// KNOWN INCONSISTENCY (deliberately left alone here to keep this change
/// scoped to Laporan): DashboardRepository._sumExpenseForDate still sums
/// `cash_movements` type = 'expense' and therefore still undercounts
/// non-cash expenses in "Total Pengeluaran Hari Ini" / "Laba Kotor Hari
/// Ini". Fixing that touches Dashboard's own numbers and should be its
/// own change.
class LaporanRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<ReportData> getPendapatanReport(DateTime month) async {
    final db = await _db;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final trend = await _dailyTrend(
      db,
      table: 'transactions',
      dateColumn: 'paid_at',
      amountColumn: 'total',
      filter: "status = 'paid'",
      year: month.year,
      month: month.month,
      daysInMonth: daysInMonth,
    );

    final totalValue = trend.fold<int>(0, (sum, p) => sum + p.value);
    final txCount = await _countForMonth(
      db,
      table: 'transactions',
      dateColumn: 'paid_at',
      filter: "status = 'paid'",
      year: month.year,
      month: month.month,
    );
    final rows = await _getPendapatanRows(db, month.year, month.month);

    return _build(totalValue: totalValue, txCount: txCount, daysInMonth: daysInMonth, trend: trend, rows: rows);
  }

  Future<ReportData> getPengeluaranReport(DateTime month) async {
    final db = await _db;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final trend = await _dailyTrend(
      db,
      table: 'cash_expenses',
      dateColumn: 'transaction_date',
      amountColumn: 'amount',
      filter: "direction = 'pengeluaran'",
      year: month.year,
      month: month.month,
      daysInMonth: daysInMonth,
    );

    final totalValue = trend.fold<int>(0, (sum, p) => sum + p.value);
    final txCount = await _countForMonth(
      db,
      table: 'cash_expenses',
      dateColumn: 'transaction_date',
      filter: "direction = 'pengeluaran'",
      year: month.year,
      month: month.month,
    );
    final rows = await _getPengeluaranRows(db, month.year, month.month);

    return _build(totalValue: totalValue, txCount: txCount, daysInMonth: daysInMonth, trend: trend, rows: rows);
  }

  ReportData _build({
    required int totalValue,
    required int txCount,
    required int daysInMonth,
    required List<ReportTrendPoint> trend,
    required List<ReportRow> rows,
  }) {
    return ReportData(
      totalValue: totalValue,
      transactionCount: txCount,
      averagePerTransaction: txCount == 0 ? 0 : (totalValue / txCount).round(),
      averagePerDay: daysInMonth == 0 ? 0 : (totalValue / daysInMonth).round(),
      trend: trend,
      rows: rows,
    );
  }

  String _monthPrefix(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  /// sqflite can hand back `int` or `double` for aggregate columns
  /// depending on the expression, so never cast an aggregate straight to
  /// `int` — a hard `as int` on a `double` throws at runtime and kills
  /// the whole report.
  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  /// One GROUP BY query for the whole month instead of one query per
  /// day. The per-day loop this replaces fired up to 31 sequential
  /// round-trips against an encrypted DB, which was slow enough that
  /// backing out of the screen mid-load routinely left the controller
  /// writing state after dispose.
  Future<List<ReportTrendPoint>> _dailyTrend(
    Database db, {
    required String table,
    required String dateColumn,
    required String amountColumn,
    required String filter,
    required int year,
    required int month,
    required int daysInMonth,
  }) async {
    final result = await db.rawQuery(
      "SELECT CAST(strftime('%d', $dateColumn) AS INTEGER) AS day, "
      "COALESCE(SUM($amountColumn), 0) AS total "
      "FROM $table "
      "WHERE $filter AND strftime('%Y-%m', $dateColumn) = ? "
      "GROUP BY day",
      [_monthPrefix(year, month)],
    );

    final byDay = <int, int>{
      for (final row in result) _asInt(row['day']): _asInt(row['total']),
    };

    return [
      for (var day = 1; day <= daysInMonth; day++) ReportTrendPoint(day: day, value: byDay[day] ?? 0),
    ];
  }

  Future<int> _countForMonth(
    Database db, {
    required String table,
    required String dateColumn,
    required String filter,
    required int year,
    required int month,
  }) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM $table WHERE $filter AND strftime('%Y-%m', $dateColumn) = ?",
      [_monthPrefix(year, month)],
    );
    return _asInt(result.first['cnt']);
  }

  Future<List<ReportRow>> _getPendapatanRows(Database db, int year, int month) async {
    final rows = await db.rawQuery(
      "SELECT display_number, customer_name, total, paid_at FROM transactions "
      "WHERE status = 'paid' AND strftime('%Y-%m', paid_at) = ? "
      "ORDER BY paid_at DESC LIMIT 50",
      [_monthPrefix(year, month)],
    );

    return rows.map((row) {
      final paidAt = _parseDate(row['paid_at']);
      // PRD: a transaction with no customer is "Pelanggan Umum".
      final customerName = (row['customer_name'] as String?)?.trim();
      final displayNumber = (row['display_number'] as String?) ?? '-';
      return ReportRow(
        title: (customerName == null || customerName.isEmpty) ? 'Pelanggan Umum' : customerName,
        subtitle: paidAt == null ? displayNumber : '$displayNumber - ${_formatDate(paidAt)}',
        amount: _asInt(row['total']),
      );
    }).toList();
  }

  Future<List<ReportRow>> _getPengeluaranRows(Database db, int year, int month) async {
    final rows = await db.rawQuery(
      "SELECT category, store_or_supplier_name, amount, transaction_date FROM cash_expenses "
      "WHERE direction = 'pengeluaran' AND strftime('%Y-%m', transaction_date) = ? "
      "ORDER BY transaction_date DESC, created_at DESC LIMIT 50",
      [_monthPrefix(year, month)],
    );

    return rows.map((row) {
      final date = _parseDate(row['transaction_date']);
      final category = (row['category'] as String?)?.trim();
      final store = (row['store_or_supplier_name'] as String?)?.trim();
      final title = (store != null && store.isNotEmpty) ? store : ((category == null || category.isEmpty) ? 'Pengeluaran' : category);
      final parts = <String>[
        if (store != null && store.isNotEmpty && category != null && category.isNotEmpty) category,
        if (date != null) _formatDate(date),
      ];
      return ReportRow(
        title: title,
        subtitle: parts.join(' - '),
        amount: _asInt(row['amount']),
      );
    }).toList();
  }

  /// Tolerant parse: a malformed/NULL timestamp degrades the one row's
  /// subtitle instead of throwing and blanking the entire report.
  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}, $hh:$mm';
  }
}
