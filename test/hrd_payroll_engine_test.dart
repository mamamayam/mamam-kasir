// Golden-value tests for the HRD payroll engine.
//
// Expected values were NOT hand-computed: they were produced by running
// hrd-mockup.html's own JavaScript payroll engine directly in Node
// (see the migration session notes) — this file checks that the Dart
// port (lib/features/hrd/domain/payroll_engine.dart) reproduces those
// exact numbers, not that the numbers "look right".
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/features/hrd/domain/hrd_models.dart';
import 'package:mamam_kasir/features/hrd/domain/hrd_seed_data.dart';
import 'package:mamam_kasir/features/hrd/domain/payroll_engine.dart';

Employee _employeeById(String id) => kHrdSeedEmployees.firstWhere((e) => e.id == id);

AttendanceLog _log(String type, String? time, {String date = '2026-09-04'}) {
  return AttendanceLog(
    id: 't',
    employeeId: 'EMP-1001',
    date: date,
    type: AttendanceLogType.values.firstWhere((t) => t.name == type),
    time: time,
  );
}

void main() {
  group('weekPeriodForDate (Friday-anchored)', () {
    const cases = {
      '2026-09-04': ('2026-09-04', '2026-09-10'), // Friday starts its own week
      '2026-09-10': ('2026-09-04', '2026-09-10'), // Thursday -> same week
      '2026-09-11': ('2026-09-11', '2026-09-17'),
      '2026-09-12': ('2026-09-11', '2026-09-17'),
      '2026-09-16': ('2026-09-11', '2026-09-17'),
      '2026-09-17': ('2026-09-11', '2026-09-17'),
      '2026-09-18': ('2026-09-18', '2026-09-24'),
      '2026-08-31': ('2026-08-28', '2026-09-03'), // crosses a month boundary
    };

    cases.forEach((date, expected) {
      test('$date -> week ${expected.$1}..${expected.$2}', () {
        final week = weekPeriodForDate(date);
        expect(week.start, expected.$1);
        expect(week.end, expected.$2);
      });
    });
  });

  group('computeDayResult — day scenarios (EMP-1001, wage 15000/h, OT 5000/30min, bonus 25000)', () {
    final employee = _employeeById('EMP-1001');

    test('s01 normal 09:00-19:00', () {
      final r = computeDayResult([_log('masuk', '09:00'), _log('pulang', '19:00')], employee, '2026-09-04', '2026-09-11');
      expect(r.status, DayStatus.hadir);
      expect(r.workedMinutes, 600);
      expect(r.overtimeMinutes, 0);
      expect(r.bolongMinutes, 0);
      expect(r.fullTimeBonus, true);
      expect(r.effectiveFromBolong, false);
    });

    test('s02 morning + evening overtime (08:25-20:15)', () {
      final r = computeDayResult([_log('masuk', '08:25'), _log('pulang', '20:15')], employee, '2026-09-04', '2026-09-11');
      expect(r.workedMinutes, 600);
      expect(r.overtimeMinutes, 110);
      expect(r.fullTimeBonus, true);
    });

    test('s03 late in / early out — no OT, no full-time bonus', () {
      final r = computeDayResult([_log('masuk', '09:10'), _log('pulang', '18:30')], employee, '2026-09-04', '2026-09-11');
      expect(r.workedMinutes, 560);
      expect(r.overtimeMinutes, 0);
      expect(r.fullTimeBonus, false);
    });

    test('s04 bolong pair inside normal hours subtracts from worked', () {
      final r = computeDayResult(
        [_log('masuk', '08:55'), _log('bolong', '13:00'), _log('masuk_lagi', '14:30'), _log('pulang', '19:00')],
        employee,
        '2026-09-04',
        '2026-09-11',
      );
      expect(r.workedMinutes, 510);
      expect(r.bolongMinutes, 90);
      expect(r.fullTimeBonus, true);
    });

    test('s05 stuck bolong, day already ended -> treated as clock-out', () {
      final r = computeDayResult([_log('masuk', '08:55'), _log('bolong', '13:00')], employee, '2026-09-04', '2026-09-11');
      expect(r.status, DayStatus.hadir);
      expect(r.workedMinutes, 240);
      expect(r.overtimeMinutes, 0);
      expect(r.fullTimeBonus, false);
      expect(r.effectiveFromBolong, true);
    });

    test('s06 stuck bolong, same day (today) -> needs clarification, no pay yet', () {
      final r = computeDayResult([_log('masuk', '08:55', date: '2026-09-11'), _log('bolong', '13:00', date: '2026-09-11')], employee, '2026-09-11', '2026-09-11');
      expect(r.status, DayStatus.perluKlarifikasi);
      expect(r.workedMinutes, 0);
      expect(r.stuckBolongTime, '13:00');
    });

    test('s07 stuck bolong with a pulang also present (inconsistent) -> still needs clarification', () {
      final r = computeDayResult(
        [_log('masuk', '08:55'), _log('bolong', '13:00'), _log('pulang', '19:00')],
        employee,
        '2026-09-04',
        '2026-09-11',
      );
      expect(r.status, DayStatus.perluKlarifikasi);
    });

    test('s08 stuck bolong, day ended, early clock-in -> morning OT still applies, no evening OT/bonus', () {
      final r = computeDayResult([_log('masuk', '08:00'), _log('bolong', '13:00')], employee, '2026-09-04', '2026-09-11');
      expect(r.workedMinutes, 240);
      expect(r.overtimeMinutes, 60);
      expect(r.fullTimeBonus, false);
      expect(r.effectiveFromBolong, true);
    });

    test('s09 libur', () {
      final r = computeDayResult([_log('libur', null)], employee, '2026-09-04', '2026-09-11');
      expect(r.status, DayStatus.libur);
    });

    test('s10 masuk only, no pulang -> belum pulang', () {
      final r = computeDayResult([_log('masuk', '09:00')], employee, '2026-09-04', '2026-09-11');
      expect(r.status, DayStatus.belumPulang);
    });

    test('s11 big overtime both sides (07:30-21:00)', () {
      final r = computeDayResult([_log('masuk', '07:30'), _log('pulang', '21:00')], employee, '2026-09-04', '2026-09-11');
      expect(r.workedMinutes, 600);
      expect(r.overtimeMinutes, 210);
      expect(r.fullTimeBonus, true);
    });

    test('s12 bolong entirely before store opens -> does not subtract from worked', () {
      final r = computeDayResult(
        [_log('masuk', '08:00'), _log('bolong', '08:10'), _log('masuk_lagi', '08:20'), _log('pulang', '19:00')],
        employee,
        '2026-09-04',
        '2026-09-11',
      );
      expect(r.workedMinutes, 600);
      expect(r.overtimeMinutes, 60);
      expect(r.bolongMinutes, 0);
    });

    test('s13 bolong straddling store-open boundary -> only the inside part subtracts', () {
      final r = computeDayResult(
        [_log('masuk', '08:00'), _log('bolong', '08:50'), _log('masuk_lagi', '09:20'), _log('pulang', '19:00')],
        employee,
        '2026-09-04',
        '2026-09-11',
      );
      expect(r.workedMinutes, 580);
      expect(r.overtimeMinutes, 60);
      expect(r.bolongMinutes, 20);
    });

    test('s14 exact thresholds (08:30 in, 19:30 out) both count as overtime', () {
      final r = computeDayResult([_log('masuk', '08:30'), _log('pulang', '19:30')], employee, '2026-09-04', '2026-09-11');
      expect(r.workedMinutes, 600);
      expect(r.overtimeMinutes, 60);
      expect(r.fullTimeBonus, true);
    });

    test('s15 just inside thresholds (08:31 in, 19:29 out) -> no overtime', () {
      final r = computeDayResult([_log('masuk', '08:31'), _log('pulang', '19:29')], employee, '2026-09-04', '2026-09-11');
      expect(r.workedMinutes, 600);
      expect(r.overtimeMinutes, 0);
      expect(r.fullTimeBonus, true);
    });

    test('s17 only a bolong log, no masuk -> belum absen (never "stuck")', () {
      final r = computeDayResult([_log('bolong', '13:00')], employee, '2026-09-04', '2026-09-11');
      expect(r.status, DayStatus.belumAbsen);
    });
  });

  group('computePayroll — monthly, all 6 seeded employees (2026-09)', () {
    const expected = {
      'EMP-1001': (hadir: 9, wage: 1324250, ot: 25000, ft: 175000, net: 1474250),
      'EMP-1002': (hadir: 8, wage: 1116033, ot: 5000, ft: 120000, net: 1291033),
      'EMP-1003': (hadir: 6, wage: 1200000, ot: 6000, ft: 180000, net: 1236000),
      'EMP-1004': (hadir: 2, wage: 208000, ot: 0, ft: 0, net: 208000),
      'EMP-1005': (hadir: 0, wage: 0, ot: 0, ft: 0, net: 0),
      'EMP-1006': (hadir: 0, wage: 0, ot: 0, ft: 0, net: 0),
    };

    expected.forEach((id, exp) {
      test('$id', () {
        final employee = _employeeById(id);
        final result = computePayroll(
          employee: employee,
          logs: kHrdSeedAttendance,
          additions: kHrdSeedAdditions,
          deductions: kHrdSeedDeductions,
          openingBalances: kHrdSeedOpeningBalances,
          period: PayPeriod.month('2026-09'),
          today: kHrdPlaceholderToday,
        );
        expect(result.attendance.hadirDays, exp.hadir, reason: 'hadirDays');
        expect(result.attendance.wagePay, exp.wage, reason: 'wagePay');
        expect(result.attendance.overtimePay, exp.ot, reason: 'overtimePay');
        expect(result.attendance.fullTimeBonusPay, exp.ft, reason: 'fullTimeBonusPay');
        expect(result.netPay, exp.net, reason: 'netPay');
      });
    });

    test('EMP-1003 opening balance reduces net pay', () {
      final result = computePayroll(
        employee: _employeeById('EMP-1003'),
        logs: kHrdSeedAttendance,
        additions: kHrdSeedAdditions,
        deductions: kHrdSeedDeductions,
        openingBalances: kHrdSeedOpeningBalances,
        period: PayPeriod.month('2026-09'),
        today: kHrdPlaceholderToday,
      );
      expect(result.openingBalance, -50000);
      expect(result.totalPenghasilan, 1386000);
      expect(result.netPay, 1236000);
    });

    test('Owner Overview totals across all employees', () {
      var wage = 0, bonus = 0, overtime = 0, deductions = 0;
      for (final e in kHrdSeedEmployees) {
        final p = computePayroll(
          employee: e,
          logs: kHrdSeedAttendance,
          additions: kHrdSeedAdditions,
          deductions: kHrdSeedDeductions,
          openingBalances: kHrdSeedOpeningBalances,
          period: PayPeriod.month('2026-09'),
          today: kHrdPlaceholderToday,
        );
        wage += p.attendance.wagePay;
        bonus += p.attendance.fullTimeBonusPay + p.additionsTotal;
        overtime += p.attendance.overtimePay;
        deductions += p.deductionsTotal;
      }
      expect(wage, 3848283);
      expect(bonus, 625000);
      expect(overtime, 36000);
      expect(deductions, 350000);
      expect(wage + bonus + overtime, 4509283);
    });
  });

  group('stuck-bolong state transitions (mirrors the controller, EMP-1002 scenario)', () {
    test('a pulang cannot coexist with an unresolved bolong (guard)', () {
      final logs = [_log('masuk', '09:00'), _log('bolong', '12:00')];
      expect(findStuckBolong(logs), isNotNull);
    });

    test('adding masuk_lagi after the bolong resolves the stuck state', () {
      final logs = [_log('masuk', '09:00'), _log('bolong', '12:00'), _log('masuk_lagi', '13:00')];
      expect(findStuckBolong(logs), isNull);
    });

    test('a second bolong after resuming can itself be stuck independently', () {
      final logs = [_log('masuk', '09:00'), _log('bolong', '12:00'), _log('masuk_lagi', '13:00'), _log('bolong', '16:00')];
      final stuck = findStuckBolong(logs);
      expect(stuck, isNotNull);
      expect(stuck!.time, '16:00');
    });
  });

  test('roundedWage rounds half up in integer arithmetic', () {
    // 90 minutes at 15000/h = 22500 exactly.
    expect(roundedWage(90, 15000), 22500);
    // 1 minute at 15000/h = 250.0 exactly.
    expect(roundedWage(1, 15000), 250);
    // 599 minutes at 15000/h = 149750.0 exactly (no rounding needed).
    expect(roundedWage(599, 15000), 149750);
  });
}
