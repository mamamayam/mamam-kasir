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

  Future<int> _sumPaidTotalForDay(Database db, int year, int month, int day) async {
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM transactions WHERE status = 'paid' AND date(paid_at) = ?",
      [dateStr],
    );
    return result.first['total'] as int;
  }

  Future<int> _sumExpenseForDay(Database db, int year, int month, int day) async {
    final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM cash_movements WHERE type = 'expense' AND date(created_at) = ?",
      [dateStr],
    );
    return result.first['total'] as int;
  }

  Future<int> _countPaidOrdersForMonth(Database db, int year, int month) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM transactions WHERE status = 'paid' AND strftime('%Y-%m', paid_at) = ?",
      [_monthPrefix(year, month)],
    );
    return result.first['cnt'] as int;
  }

  Future<int> _countExpensesForMonth(Database db, int year, int month) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM cash_movements WHERE type = 'expense' AND strftime('%Y-%m', created_at) = ?",
      [_monthPrefix(year, month)],
    );
    return result.first['cnt'] as int;
  }

  Future<List<ReportRow>> _getPendapatanRows(Database db, int year, int month) async {
    final rows = await db.rawQuery(
      "SELECT * FROM transactions WHERE status = 'paid' AND strftime('%Y-%m', paid_at) = ? ORDER BY paid_at DESC LIMIT 50",
      [_monthPrefix(year, month)],
    );
    return rows.map((row) {
      final paidAt = DateTime.parse(row['paid_at'] as String);
      final customerName = row['customer_name'] as String? ?? 'Pelanggan';
      return ReportRow(
        title: customerName,
        subtitle: 'Mamam Ayam - ${_formatDate(paidAt)}',
        amount: row['total'] as int,
      );
    }).toList();
  }

  Future<List<ReportRow>> _getPengeluaranRows(Database db, int year, int month) async {
    final rows = await db.rawQuery(
      "SELECT * FROM cash_movements WHERE type = 'expense' AND strftime('%Y-%m', created_at) = ? ORDER BY created_at DESC LIMIT 50",
      [_monthPrefix(year, month)],
    );
    return rows.map((row) {
      final createdAt = DateTime.parse(row['created_at'] as String);
      final reason = row['reason'] as String? ?? 'Belanja';
      return ReportRow(
        title: reason,
        subtitle: 'Mamam Ayam - ${_formatDate(createdAt)}',
        amount: row['amount'] as int,
      );
    }).toList();
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}, $hh:$mm';
  }
}
