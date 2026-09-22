/// Domain models for the Modul Karyawan (HRD) PLACEHOLDER.
///
/// ⚠️ PLACEHOLDER SCOPE — read before extending.
/// AGENTS.md lists "full HRD/payroll" under Forbidden scope and says the
/// external attendance system is the source of truth (`AttendanceProvider`
/// port only). This module exists because the owner explicitly asked for
/// the HTML mockup (hrd-mockup.html) to be brought into the app as an
/// in-memory placeholder. Nothing here is persisted, synced, audited or
/// permission-checked. Do not build real HRD/payroll on top of it without
/// updating the PRD first.
///
/// Money is always integer Rupiah (AGENTS.md: never floating-point).
/// Dates are ISO `yyyy-MM-dd` strings and times are `HH:mm` strings, the
/// same shapes the mockup uses, so the payroll engine stays a direct,
/// testable port of the validated mockup logic.
library;

enum EmployeeStatus { aktif, freelance, cuti, resign }

extension EmployeeStatusLabel on EmployeeStatus {
  String get label => switch (this) {
        EmployeeStatus.aktif => 'Aktif',
        EmployeeStatus.freelance => 'Freelance',
        EmployeeStatus.cuti => 'Cuti',
        EmployeeStatus.resign => 'Resign',
      };
}

/// Raw attendance event. Daily worked hours, overtime and Bonus Full Time
/// are always DERIVED from these rows, never stored separately.
enum AttendanceLogType { masuk, masukLagi, bolong, pulang, libur }

extension AttendanceLogTypeLabel on AttendanceLogType {
  String get label => switch (this) {
        AttendanceLogType.masuk => 'Masuk',
        AttendanceLogType.masukLagi => 'Masuk Lagi',
        AttendanceLogType.bolong => 'Jam Bolong',
        AttendanceLogType.pulang => 'Pulang',
        AttendanceLogType.libur => 'Libur',
      };
}

/// Status of one employee's day, as derived by the payroll engine.
/// [perluKlarifikasi] = the employee is "stuck": a `bolong` log exists
/// with no `masuk_lagi` after it (see payroll_engine.dart).
enum DayStatus { hadir, libur, belumAbsen, belumPulang, perluKlarifikasi }

enum PayrollSource { owner, staff }

enum HrdApprovalType { income, attendanceClarification }

enum HrdApprovalStatus { menunggu, disetujui, ditolak }

extension HrdApprovalStatusLabel on HrdApprovalStatus {
  String get label => switch (this) {
        HrdApprovalStatus.menunggu => 'Menunggu',
        HrdApprovalStatus.disetujui => 'Disetujui',
        HrdApprovalStatus.ditolak => 'Ditolak',
      };
}

/// Owner-managed job role. [locked] roles (Manajer) can never be renamed
/// or removed: Manajer is a fixed permission level one step below Owner,
/// not a free-form job title.
class HrdRole {
  final String id;
  final String name;
  final bool locked;

  const HrdRole({required this.id, required this.name, this.locked = false});
}

class Employee {
  final String id;
  final String name;
  final String phone;
  final String address;
  final EmployeeStatus status;
  final String? resignDate;

  /// Role NAME (matches [HrdRole.name]) — same shape as the mockup.
  final String role;
  final int wagePerHour;
  final int bonusFullTime;
  final int overtimeRatePer30Min;
  final String startDate;

  const Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.status,
    this.resignDate,
    required this.role,
    required this.wagePerHour,
    required this.bonusFullTime,
    required this.overtimeRatePer30Min,
    required this.startDate,
  });

  Employee copyWith({
    String? name,
    String? phone,
    String? address,
    EmployeeStatus? status,
    String? resignDate,
    bool clearResignDate = false,
    String? role,
    int? wagePerHour,
    int? bonusFullTime,
    int? overtimeRatePer30Min,
    String? startDate,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      status: status ?? this.status,
      resignDate: clearResignDate ? null : (resignDate ?? this.resignDate),
      role: role ?? this.role,
      wagePerHour: wagePerHour ?? this.wagePerHour,
      bonusFullTime: bonusFullTime ?? this.bonusFullTime,
      overtimeRatePer30Min: overtimeRatePer30Min ?? this.overtimeRatePer30Min,
      startDate: startDate ?? this.startDate,
    );
  }
}

class AttendanceLog {
  final String id;
  final String employeeId;
  final String date;
  final AttendanceLogType type;

  /// `HH:mm`. Null only for [AttendanceLogType.libur].
  final String? time;

  /// True for a `libur` row the system inferred (employee never clocked in).
  final bool auto;

  const AttendanceLog({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.type,
    this.time,
    this.auto = false,
  });

  AttendanceLog copyWith({String? time, AttendanceLogType? type}) {
    return AttendanceLog(
      id: id,
      employeeId: employeeId,
      date: date,
      type: type ?? this.type,
      time: time ?? this.time,
      auto: auto,
    );
  }
}

/// Manual earning added on top of attendance-derived pay (Bonus, THR,
/// Ongkir, ...). Owner-entered rows are always already effective; staff
/// income only lands here after an approved [HrdApprovalRequest].
class PayrollAddition {
  final String id;
  final String employeeId;
  final String label;
  final int amount;
  final String date;
  final String category;
  final PayrollSource source;
  final String? approvedBy;
  final String? approvedAt;

  const PayrollAddition({
    required this.id,
    required this.employeeId,
    required this.label,
    required this.amount,
    required this.date,
    required this.category,
    required this.source,
    this.approvedBy,
    this.approvedAt,
  });
}

/// Manual deduction (Kasbon, Potongan Lainnya, staff-entered pengeluaran).
class PayrollDeduction {
  final String id;
  final String employeeId;
  final String label;
  final int amount;
  final String date;
  final String category;

  const PayrollDeduction({
    required this.id,
    required this.employeeId,
    required this.label,
    required this.amount,
    required this.date,
    required this.category,
  });
}

/// One pending/decided approval item. Kept generic via [type] (income
/// request vs attendance clarification) so a future shared Approval
/// feature can absorb it — but named `Hrd…` on purpose so it never
/// collides with that feature's own model.
class HrdApprovalRequest {
  final String id;
  final HrdApprovalType type;
  final String employeeId;
  final String date;
  final HrdApprovalStatus status;

  // type == income
  final String? label;
  final int? amount;
  final String? note;

  // type == attendanceClarification
  final String? bolongTime;

  final String? decidedBy;
  final String? decidedAt;
  final String? resolution;

  const HrdApprovalRequest({
    required this.id,
    required this.type,
    required this.employeeId,
    required this.date,
    required this.status,
    this.label,
    this.amount,
    this.note,
    this.bolongTime,
    this.decidedBy,
    this.decidedAt,
    this.resolution,
  });

  HrdApprovalRequest copyWith({
    HrdApprovalStatus? status,
    String? decidedBy,
    String? decidedAt,
    String? resolution,
  }) {
    return HrdApprovalRequest(
      id: id,
      type: type,
      employeeId: employeeId,
      date: date,
      status: status ?? this.status,
      label: label,
      amount: amount,
      note: note,
      bolongTime: bolongTime,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
      resolution: resolution ?? this.resolution,
    );
  }
}
