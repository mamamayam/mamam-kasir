import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../domain/dashboard_models.dart';

/// Reads dashboard figures from the same `transactions` / `cash_movements`
/// tables every other feature writes to — no separate "dashboard data"
/// store. Mirrors the query style already used in DompetRepository
/// (raw SQL against sqflite, computed on read rather than cached).
class DashboardRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<DashboardMetrics> getMetrics() async {
    final db = await _db;

    final todayOmzet = await _sumPaidTotalForDate(db, _today());
    final yesterdayOmzet = await _sumPaidTotalForDate(db, _today().subtract(const Duration(days: 1)));
    final todayExpense = await _sumExpenseForDate(db, _today());
    final todayOrderCount = await _countPaidOrdersForDate(db, _today());

    final labaKotor = todayOmzet - todayExpense;
    final rataRata = todayOrderCount == 0 ? 0 : (todayOmzet / todayOrderCount).round();
    // Growth vs. yesterday; 0% rather than a divide-by-zero/infinite
    // figure when yesterday had no sales to compare against.
    final growthPercent = yesterdayOmzet == 0 ? 0.0 : ((todayOmzet - yesterdayOmzet) / yesterdayOmzet) * 100;

    return DashboardMetrics(
      omzetHariIni: todayOmzet,
      totalPengeluaran: todayExpense,
      labaKotor: labaKotor,
      totalPesanan: todayOrderCount,
      rataRata: rataRata,
      growthPercent: growthPercent,
    );
  }

  /// Last 31 days of paid-order totals, oldest first — one point per
  /// calendar day, 0 for days with no paid transactions (not omitted,
  /// so the chart's x-axis stays continuous).
  Future<List<SalesTrendPoint>> getSalesTrend({int days = 31}) async {
    final db = await _db;
    final points = <SalesTrendPoint>[];

    for (var i = days - 1; i >= 0; i--) {
      final date = _today().subtract(Duration(days: i));
      final total = await _sumPaidTotalForDate(db, date);
      final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      points.add(SalesTrendPoint(date: date, value: total, isWeekend: isWeekend));
    }

    return points;
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<int> _sumPaidTotalForDate(Database db, DateTime date) async {
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) as total FROM transactions WHERE status = 'paid' AND date(paid_at) = ?",
      [_dateOnly(date)],
    );
    return result.first['total'] as int;
  }

  Future<int> _countPaidOrdersForDate(Database db, DateTime date) async {
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM transactions WHERE status = 'paid' AND date(paid_at) = ?",
      [_dateOnly(date)],
    );
    return result.first['cnt'] as int;
  }

  /// Expenses aren't a separate feature yet — the only "money leaving
  /// the business" rows that exist today are `cash_movements` of type
  /// 'expense' (per the Dompet ledger schema). Once a dedicated Expenses
  /// module exists this should read from it instead/in addition.
  Future<int> _sumExpenseForDate(Database db, DateTime date) async {
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM cash_movements WHERE type = 'expense' AND date(created_at) = ?",
      [_dateOnly(date)],
    );
    return result.first['total'] as int;
  }
}
