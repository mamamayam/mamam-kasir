import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../domain/laporan_models.dart';

/// Reads Pendapatan/Pengeluaran report data for a given month from the
/// same `transactions` / `cash_movements` tables as Dashboard — same
/// "compute on read, no separate reports store" approach as
/// DashboardRepository/DompetRepository.
class LaporanRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<ReportData> getPendapatanReport(DateTime month) async {
    final db = await _db;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final trend = <ReportTrendPoint>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final total = await _sumPaidTotalForDay(db, month.year, month.month, day);
      trend.add(ReportTrendPoint(day: day, value: total));
    }

    final totalValue = trend.fold<int>(0, (sum, p) => sum + p.value);
    final txCount = await _countPaidOrdersForMonth(db, month.year, month.month);
    final rows = await _getPendapatanRows(db, month.year, month.month);

    return ReportData(
      totalValue: totalValue,
      transactionCount: txCount,
      averagePerTransaction: txCount == 0 ? 0 : (totalValue / txCount).round(),
      averagePerDay: (totalValue / daysInMonth).round(),
      trend: trend,
      rows: rows,
    );
  }

  Future<ReportData> getPengeluaranReport(DateTime month) async {
    final db = await _db;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final trend = <ReportTrendPoint>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final total = await _sumExpenseForDay(db, month.year, month.month, day);
      trend.add(ReportTrendPoint(day: day, value: total));
    }

    final totalValue = trend.fold<int>(0, (sum, p) => sum + p.value);
    final txCount = await _countExpensesForMonth(db, month.year, month.month);
    final rows = await _getPengeluaranRows(db, month.year, month.month);

    return ReportData(
      totalValue: totalValue,
      transactionCount: txCount,
      averagePerTransaction: txCount == 0 ? 0 : (totalValue / txCount).round(),
      averagePerDay: (totalValue / daysInMonth).round(),
      trend: trend,
      rows: rows,
    );
  }

  String _monthPrefix(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

  /// SQLite's SUM()/COUNT() can hand back either an int or a double
  /// depending on platform/driver and whether any floating-point value
  /// was seen during aggregation — casting straight `as int` on that
  /// column threw and silently blanked this whole report whenever the
  /// driver returned a double. Route every numeric column read through
  /// this so an unexpected num subtype never crashes the report.
  int _asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<int> _sumPaidTotalForDay(Database db, int year, int month, int day) async {
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM transactions WHERE status = 'paid' AND date(paid_at) = ?",
      [dateStr],
    );
    return _asInt(result.first['total']);
  }

  Future<int> _sumExpenseForDay(Database db, int year, int month, int day) async {
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM cash_movements WHERE type = 'expense' AND date(created_at) = ?",
      [dateStr],
    );
    return _asInt(result.first['total']);
  }

  Future<int> _countPaidOrdersForMonth(Database db, int year, int month) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM transactions WHERE status = 'paid' AND strftime('%Y-%m', paid_at) = ?",
      [_monthPrefix(year, month)],
    );
    return _asInt(result.first['cnt']);
  }

  Future<int> _countExpensesForMonth(Database db, int year, int month) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM cash_movements WHERE type = 'expense' AND strftime('%Y-%m', created_at) = ?",
      [_monthPrefix(year, month)],
    );
    return _asInt(result.first['cnt']);
  }

  Future<List<ReportRow>> _getPendapatanRows(Database db, int year, int month) async {
    final rows = await db.rawQuery(
      "SELECT * FROM transactions WHERE status = 'paid' AND strftime('%Y-%m', paid_at) = ? ORDER BY paid_at DESC LIMIT 50",
      [_monthPrefix(year, month)],
    );
    final result = <ReportRow>[];
    for (final row in rows) {
      // One malformed row (missing/unparseable paid_at, unexpected
      // numeric type) used to throw and blank the entire report instead
      // of just dropping that row.
      try {
        final rawPaidAt = row['paid_at'];
        final paidAt = rawPaidAt is String ? DateTime.parse(rawPaidAt) : DateTime.now();
        final customerName = row['customer_name'] as String? ?? 'Pelanggan';
        result.add(ReportRow(
          title: customerName,
          subtitle: 'Mamam Ayam - ${_formatDate(paidAt)}',
          amount: _asInt(row['total']),
        ));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  Future<List<ReportRow>> _getPengeluaranRows(Database db, int year, int month) async {
    final rows = await db.rawQuery(
      "SELECT * FROM cash_movements WHERE type = 'expense' AND strftime('%Y-%m', created_at) = ? ORDER BY created_at DESC LIMIT 50",
      [_monthPrefix(year, month)],
    );
    final result = <ReportRow>[];
    for (final row in rows) {
      try {
        final rawCreatedAt = row['created_at'];
        final createdAt = rawCreatedAt is String ? DateTime.parse(rawCreatedAt) : DateTime.now();
        final reason = row['reason'] as String? ?? 'Belanja';
        result.add(ReportRow(
          title: reason,
          subtitle: 'Mamam Ayam - ${_formatDate(createdAt)}',
          amount: _asInt(row['amount']),
        ));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}, $hh:$mm';
  }
}
