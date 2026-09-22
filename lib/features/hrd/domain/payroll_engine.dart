/// Payroll engine — direct, UI-independent port of the payroll logic in
/// hrd-mockup.html (validated there; golden values in
/// `test/hrd_payroll_engine_test.dart` were produced by running the
/// mockup's own JavaScript, not hand-computed).
///
/// Rules (PRD of the mockup / migration prompt — do not "improve"):
/// * Store hours are fixed 09:00–19:00 for everyone.
/// * Morning overtime: clock-in <= 08:30 -> (09:00 - clock-in) minutes.
/// * Evening overtime: clock-out >= 19:30 -> (clock-out - 19:00) minutes.
/// * Overtime pay = floor(total OT minutes / 30) blocks x per-employee rate.
/// * Wage pay counts ONLY minutes inside 09:00–19:00. Time outside that
///   window is paid solely through overtime, never twice.
/// * Bolong (break) gaps — bolong -> next masuk_lagi — are subtracted, but
///   only the part that falls inside paid normal hours.
/// * Bonus Full Time: clock-in <= 09:00 AND clock-out >= 19:00, per day.
/// * A "stuck" bolong (no masuk_lagi after it) is NEVER auto-treated as
///   clock-out on the same day. It only becomes the final clock-out once
///   the day has ended, or when the owner/manager confirms it manually.
/// * Net = wage + full-time bonus + overtime + additions - deductions
///   - opening balance (opening balance is monthly-only).
///
/// One calculation function takes any inclusive date range, so monthly
/// and weekly (Friday–Thursday) modes can never drift apart.
library;

import 'hrd_date_utils.dart';
import 'hrd_models.dart';

// ---------------------------------------------------------------------------
// Constants (minutes since midnight)
// ---------------------------------------------------------------------------

const int storeStartMinutes = 9 * 60; // 09:00
const int storeEndMinutes = 19 * 60; // 19:00
const int overtimeMorningThresholdMinutes = 8 * 60 + 30; // 08:30
const int overtimeEveningThresholdMinutes = 19 * 60 + 30; // 19:30
const int defaultOvertimeRatePer30Min = 5000;

// ---------------------------------------------------------------------------
// Period
// ---------------------------------------------------------------------------

/// Inclusive date range used by every payroll calculation.
class PayPeriod {
  final String start;
  final String end;
  final bool isMonth;

  const PayPeriod._(this.start, this.end, this.isMonth);

  /// Whole calendar month, e.g. `PayPeriod.month('2026-09')`.
  factory PayPeriod.month(String yyyyMm) {
    final year = int.parse(yyyyMm.substring(0, 4));
    final month = int.parse(yyyyMm.substring(5, 7));
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    return PayPeriod._('$yyyyMm-01', '$yyyyMm-${lastDay.toString().padLeft(2, '0')}', true);
  }

  /// Arbitrary inclusive range (used for weekly pay weeks).
  factory PayPeriod.range(String startIso, String endIso) => PayPeriod._(startIso, endIso, false);

  /// `yyyy-MM` for monthly periods, null for weekly ones. Opening balance
  /// ("Saldo Awal Bulan") only exists for monthly periods.
  String? get monthKey => isMonth ? start.substring(0, 7) : null;

  bool contains(String isoDate) => isoDate.compareTo(start) >= 0 && isoDate.compareTo(end) <= 0;
}

/// Pay week containing [dateIso]: paid every Friday, calculated
/// Friday–Thursday (Friday is day 1). A Friday starts its own week.
PayPeriod weekPeriodForDate(String dateIso) {
  final d = parseIsoDate(dateIso);
  final dow = d.weekday % 7; // DateTime: Mon=1..Sun=7 -> Sun=0, Fri=5
  final daysSinceFriday = (dow - 5 + 7) % 7;
  final friday = d.subtract(Duration(days: daysSinceFriday));
  final thursday = friday.add(const Duration(days: 6));
  return PayPeriod.range(formatIsoDate(friday), formatIsoDate(thursday));
}

/// Moves a pay week forward/backward by whole days (normally +/-7).
PayPeriod shiftWeek(PayPeriod week, int deltaDays) {
  final moved = parseIsoDate(week.start).add(Duration(days: deltaDays));
  return weekPeriodForDate(formatIsoDate(moved));
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class DayResult {
  final DayStatus status;
  final int workedMinutes;
  final int overtimeMinutes;
  final int bolongMinutes;
  final bool fullTimeBonus;

  /// True when an unresolved bolong was treated as the clock-out because
  /// the day already ended.
  final bool effectiveFromBolong;

  /// Set only for [DayStatus.perluKlarifikasi].
  final String? stuckBolongTime;

  const DayResult({
    required this.status,
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.bolongMinutes = 0,
    this.fullTimeBonus = false,
    this.effectiveFromBolong = false,
    this.stuckBolongTime,
  });
}

class AttendanceSummary {
  final List<DayResult> dayRows;
  final int hadirDays;
  final int liburDays;
  final int fullTimeDays;
  final int totalWorkedMinutes;
  final int totalOvertimeMinutes;
  final int overtimeBlocks30Min;
  final int overtimeRate;
  final int wagePay;
  final int overtimePay;
  final int fullTimeBonusPay;

  const AttendanceSummary({
    required this.dayRows,
    required this.hadirDays,
    required this.liburDays,
    required this.fullTimeDays,
    required this.totalWorkedMinutes,
    required this.totalOvertimeMinutes,
    required this.overtimeBlocks30Min,
    required this.overtimeRate,
    required this.wagePay,
    required this.overtimePay,
    required this.fullTimeBonusPay,
  });

  double get totalWorkedHours => totalWorkedMinutes / 60;
}

class PayrollResult {
  final AttendanceSummary attendance;
  final List<PayrollAddition> additions;
  final List<PayrollDeduction> deductions;
  final int additionsTotal;
  final int deductionsTotal;
  final int openingBalance;
  final int totalPenghasilan;
  final int netPay;

  const PayrollResult({
    required this.attendance,
    required this.additions,
    required this.deductions,
    required this.additionsTotal,
    required this.deductionsTotal,
    required this.openingBalance,
    required this.totalPenghasilan,
    required this.netPay,
  });
}

// ---------------------------------------------------------------------------
// Day-level rules
// ---------------------------------------------------------------------------

int _minutesOf(AttendanceLog log) => timeToMinutes(log.time!);

bool _hasTime(AttendanceLog log) => log.time != null;

AttendanceLog? _firstOfType(List<AttendanceLog> logs, AttendanceLogType type) {
  for (final l in logs) {
    if (l.type == type) return l;
  }
  return null;
}

/// The first `bolong` that has no `masuk_lagi` after it on the same day —
/// i.e. the employee is still on break as far as the log shows.
AttendanceLog? findStuckBolong(List<AttendanceLog> dayLogs) {
  final bolongs = dayLogs.where((l) => l.type == AttendanceLogType.bolong && _hasTime(l)).toList()
    ..sort((a, b) => _minutesOf(a).compareTo(_minutesOf(b)));
  for (final b in bolongs) {
    final hasResumeAfter = dayLogs.any(
      (l) => l.type == AttendanceLogType.masukLagi && _hasTime(l) && _minutesOf(l) > _minutesOf(b),
    );
    if (!hasResumeAfter) return b;
  }
  return null;
}

/// Evaluates one employee-day from that day's raw logs.
///
/// [date] and [today] are ISO dates; "the day has ended" means
/// `date < today`.
DayResult computeDayResult(List<AttendanceLog> dayLogs, Employee employee, String date, String today) {
  final masuk = _firstOfType(dayLogs, AttendanceLogType.masuk);
  final pulang = _firstOfType(dayLogs, AttendanceLogType.pulang);
  final libur = _firstOfType(dayLogs, AttendanceLogType.libur);
  final stuck = masuk != null ? findStuckBolong(dayLogs) : null;
  final dayHasEnded = date.compareTo(today) < 0;

  if (libur != null || masuk == null) {
    return DayResult(status: libur != null ? DayStatus.libur : DayStatus.belumAbsen);
  }

  if (stuck != null) {
    // Same day, or a `pulang` coexisting with an unresolved bolong (an
    // inconsistent state we never silently guess about): needs a human.
    if (pulang != null || !dayHasEnded) {
      return DayResult(status: DayStatus.perluKlarifikasi, stuckBolongTime: stuck.time);
    }
    // Day is over and nobody clarified: the bolong is the final clock-out.
    return _resultWithClockOut(dayLogs, masuk, _minutesOf(stuck), effectiveFromBolong: true);
  }

  if (pulang == null) return const DayResult(status: DayStatus.belumPulang);

  return _resultWithClockOut(dayLogs, masuk, _minutesOf(pulang), effectiveFromBolong: false);
}

DayResult _resultWithClockOut(
  List<AttendanceLog> dayLogs,
  AttendanceLog masuk,
  int clockOutMinutes, {
  required bool effectiveFromBolong,
}) {
  final masukMin = _minutesOf(masuk);
  final pulangMin = clockOutMinutes;

  // Overtime: morning (in <= 08:30) + evening (out >= 19:30). A bolong
  // used as clock-out can never produce evening overtime.
  var overtimeMinutes = 0;
  if (masukMin <= overtimeMorningThresholdMinutes) {
    overtimeMinutes += storeStartMinutes - masukMin;
  }
  if (!effectiveFromBolong && pulangMin >= overtimeEveningThresholdMinutes) {
    overtimeMinutes += pulangMin - storeEndMinutes;
  }

  // Paid-at-regular-rate minutes are clamped INTO store hours. Time
  // outside 09:00–19:00 is overtime only (never counted twice).
  final normalStart = masukMin > storeStartMinutes ? masukMin : storeStartMinutes;
  final normalEnd = pulangMin < storeEndMinutes ? pulangMin : storeEndMinutes;
  final grossNormalMinutes = normalEnd - normalStart > 0 ? normalEnd - normalStart : 0;

  // Subtract bolong -> masuk_lagi gaps, only the part inside normal hours.
  var bolongMinutes = 0;
  for (final b in dayLogs.where((l) => l.type == AttendanceLogType.bolong && _hasTime(l))) {
    final bMin = _minutesOf(b);
    final resumes = dayLogs.where((l) => l.type == AttendanceLogType.masukLagi && _hasTime(l) && _minutesOf(l) > bMin).toList()
      ..sort((x, y) => _minutesOf(x).compareTo(_minutesOf(y)));
    if (resumes.isEmpty) continue; // the stuck one has no gap to subtract
    final resumeMin = _minutesOf(resumes.first);
    final gapStart = bMin > normalStart ? bMin : normalStart;
    final gapEnd = resumeMin < normalEnd ? resumeMin : normalEnd;
    if (gapEnd - gapStart > 0) bolongMinutes += gapEnd - gapStart;
  }

  final worked = grossNormalMinutes - bolongMinutes;
  return DayResult(
    status: DayStatus.hadir,
    workedMinutes: worked > 0 ? worked : 0,
    overtimeMinutes: overtimeMinutes,
    bolongMinutes: bolongMinutes,
    fullTimeBonus: !effectiveFromBolong && masukMin <= storeStartMinutes && pulangMin >= storeEndMinutes,
    effectiveFromBolong: effectiveFromBolong,
  );
}

// ---------------------------------------------------------------------------
// Period-level rules
// ---------------------------------------------------------------------------

/// Attendance-derived pay for one employee over [period].
AttendanceSummary computeAttendance(
  Employee employee,
  List<AttendanceLog> allLogs,
  PayPeriod period,
  String today,
) {
  final byDate = <String, List<AttendanceLog>>{};
  for (final l in allLogs) {
    if (l.employeeId == employee.id && period.contains(l.date)) {
      byDate.putIfAbsent(l.date, () => []).add(l);
    }
  }
  final dates = byDate.keys.toList()..sort();

  var totalWorkedMinutes = 0;
  var totalOvertimeMinutes = 0;
  var fullTimeDays = 0;
  var hadirDays = 0;
  var liburDays = 0;
  final dayRows = <DayResult>[];

  for (final date in dates) {
    final r = computeDayResult(byDate[date]!, employee, date, today);
    if (r.status == DayStatus.hadir) {
      hadirDays++;
      totalWorkedMinutes += r.workedMinutes;
      totalOvertimeMinutes += r.overtimeMinutes;
      if (r.fullTimeBonus) fullTimeDays++;
    } else if (r.status == DayStatus.libur) {
      liburDays++;
    }
    dayRows.add(r);
  }

  final overtimeBlocks = totalOvertimeMinutes ~/ 30; // floor, per rule
  final overtimeRate = employee.overtimeRatePer30Min > 0 ? employee.overtimeRatePer30Min : defaultOvertimeRatePer30Min;

  return AttendanceSummary(
    dayRows: dayRows,
    hadirDays: hadirDays,
    liburDays: liburDays,
    fullTimeDays: fullTimeDays,
    totalWorkedMinutes: totalWorkedMinutes,
    totalOvertimeMinutes: totalOvertimeMinutes,
    overtimeBlocks30Min: overtimeBlocks,
    overtimeRate: overtimeRate,
    wagePay: roundedWage(totalWorkedMinutes, employee.wagePerHour),
    overtimePay: overtimeBlocks * overtimeRate,
    fullTimeBonusPay: fullTimeDays * employee.bonusFullTime,
  );
}

/// `round(minutes / 60 * wagePerHour)` in exact integer arithmetic
/// (half rounds up; inputs are never negative).
int roundedWage(int minutes, int wagePerHour) => (minutes * wagePerHour + 30) ~/ 60;

/// Full payroll for one employee over [period].
///
/// [openingBalances] is keyed `'<employeeId>|<yyyy-MM>'` and only applies
/// to monthly periods (positive = employee owes the company; negative =
/// the company owes the employee).
PayrollResult computePayroll({
  required Employee employee,
  required List<AttendanceLog> logs,
  required List<PayrollAddition> additions,
  required List<PayrollDeduction> deductions,
  required Map<String, int> openingBalances,
  required PayPeriod period,
  required String today,
}) {
  final attendance = computeAttendance(employee, logs, period, today);
  final periodAdditions = additions.where((a) => a.employeeId == employee.id && period.contains(a.date)).toList();
  final periodDeductions = deductions.where((d) => d.employeeId == employee.id && period.contains(d.date)).toList();
  final additionsTotal = periodAdditions.fold<int>(0, (sum, a) => sum + a.amount);
  final deductionsTotal = periodDeductions.fold<int>(0, (sum, d) => sum + d.amount);
  final monthKey = period.monthKey;
  final openingBalance = monthKey == null ? 0 : (openingBalances['${employee.id}|$monthKey'] ?? 0);

  final totalPenghasilan = attendance.wagePay + attendance.fullTimeBonusPay + attendance.overtimePay + additionsTotal;
  final netPay = totalPenghasilan - deductionsTotal - openingBalance;

  return PayrollResult(
    attendance: attendance,
    additions: periodAdditions,
    deductions: periodDeductions,
    additionsTotal: additionsTotal,
    deductionsTotal: deductionsTotal,
    openingBalance: openingBalance,
    totalPenghasilan: totalPenghasilan,
    netPay: netPay,
  );
}

// ---------------------------------------------------------------------------
// "Right now" helpers (Kehadiran Hari Ini, list badges)
// ---------------------------------------------------------------------------

/// Today's status for one employee from today's logs only.
DayStatus todayStatus(List<AttendanceLog> todayLogs, Employee employee, String today) {
  if (todayLogs.isEmpty) return DayStatus.belumAbsen;
  return computeDayResult(todayLogs, employee, today, today).status;
}

/// "Sedang Jaga": clocked in today, not clocked out, and not stuck
/// mid-bolong.
bool isOnShiftNow(List<AttendanceLog> todayLogs) {
  final hasMasuk = todayLogs.any((l) => l.type == AttendanceLogType.masuk);
  final hasPulang = todayLogs.any((l) => l.type == AttendanceLogType.pulang);
  final stuck = hasMasuk ? findStuckBolong(todayLogs) : null;
  return hasMasuk && !hasPulang && stuck == null;
}
