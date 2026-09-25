import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session.dart';
import '../../../core/session/app_session_provider.dart';
import '../domain/hrd_date_utils.dart';
import '../domain/hrd_models.dart';
import '../domain/hrd_seed_data.dart';
import '../domain/payroll_engine.dart';

// ---------------------------------------------------------------------------
// Who is looking at the module
// ---------------------------------------------------------------------------

/// Which single flow the current session may see.
///
/// [owner] -> full Owner flow (Overview, Kelola Karyawan, ...). The Staff
/// PIN flow must not exist for this session at all.
/// [sharedDevice] -> only the Staff flow (pick name -> PIN -> personal pay
/// data). The Owner flow must not exist for this session at all.
enum HrdViewerMode { owner, sharedDevice }

/// Now derived from the real logged-in session (see
/// [[mamam-kasir-flutter]]/app_session.dart) rather than an env-var
/// placeholder — Owner/Manager login -> [HrdViewerMode.owner], Staff
/// login -> [HrdViewerMode.sharedDevice]. Manager is temporarily treated
/// as Owner-equivalent here (Tahap A decision) until A4's granular
/// PermissionService replaces this role-based check with a real
/// per-permission-key lookup. This was the intended seam per the
/// original placeholder's doc comment; kept as its own provider (rather
/// than inlining the check at every call site) so HRD code doesn't need
/// to know about [AppRole] directly.
final hrdViewerModeProvider = Provider<HrdViewerMode>((ref) {
  final role = ref.watch(appSessionProvider.select((s) => s.role));
  return role == AppRole.staff ? HrdViewerMode.sharedDevice : HrdViewerMode.owner;
});

// ---------------------------------------------------------------------------
// Action result (controller -> UI feedback)
// ---------------------------------------------------------------------------

class HrdActionResult {
  final bool ok;
  final String message;

  /// Id of the entity a successful save created/updated (e.g. new employee).
  final String? savedId;

  const HrdActionResult.success(this.message, {this.savedId}) : ok = true;
  const HrdActionResult.failure(this.message)
      : ok = false,
        savedId = null;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum PayrollPeriodMode { bulanan, mingguan }

class HrdState {
  final List<HrdRole> roles;
  final List<Employee> employees;
  final List<AttendanceLog> attendance;
  final List<PayrollAddition> additions;
  final List<PayrollDeduction> deductions;
  final List<HrdApprovalRequest> approvals;
  final Map<String, int> openingBalances;

  /// Fixed reference "today" of the placeholder data set (see seed file).
  final String today;
  final String currentMonth;

  /// Period selection SHARED by Rekap Penggajian and Slip Gaji: switching
  /// to Mingguan + a week on one screen carries into the other.
  final PayrollPeriodMode periodMode;
  final PayPeriod selectedWeek;

  const HrdState({
    required this.roles,
    required this.employees,
    required this.attendance,
    required this.additions,
    required this.deductions,
    required this.approvals,
    required this.openingBalances,
    required this.today,
    required this.currentMonth,
    required this.periodMode,
    required this.selectedWeek,
  });

  factory HrdState.seed() {
    return HrdState(
      roles: kHrdSeedRoles,
      employees: kHrdSeedEmployees,
      attendance: kHrdSeedAttendance,
      additions: kHrdSeedAdditions,
      deductions: kHrdSeedDeductions,
      approvals: kHrdSeedApprovals,
      openingBalances: kHrdSeedOpeningBalances,
      today: kHrdPlaceholderToday,
      currentMonth: kHrdPlaceholderMonth,
      periodMode: PayrollPeriodMode.bulanan,
      selectedWeek: weekPeriodForDate(kHrdPlaceholderToday),
    );
  }

  HrdState copyWith({
    List<HrdRole>? roles,
    List<Employee>? employees,
    List<AttendanceLog>? attendance,
    List<PayrollAddition>? additions,
    List<PayrollDeduction>? deductions,
    List<HrdApprovalRequest>? approvals,
    PayrollPeriodMode? periodMode,
    PayPeriod? selectedWeek,
  }) {
    return HrdState(
      roles: roles ?? this.roles,
      employees: employees ?? this.employees,
      attendance: attendance ?? this.attendance,
      additions: additions ?? this.additions,
      deductions: deductions ?? this.deductions,
      approvals: approvals ?? this.approvals,
      openingBalances: openingBalances,
      today: today,
      currentMonth: currentMonth,
      periodMode: periodMode ?? this.periodMode,
      selectedWeek: selectedWeek ?? this.selectedWeek,
    );
  }

  // ---- lookups -----------------------------------------------------------

  Employee? employeeById(String id) {
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  HrdRole? roleById(String id) {
    for (final r in roles) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Employee> get activeEmployees => employees.where((e) => e.status == EmployeeStatus.aktif).toList();

  /// Employees shown on "Kehadiran Hari Ini" and the staff name list.
  List<Employee> get workingEmployees =>
      employees.where((e) => e.status == EmployeeStatus.aktif || e.status == EmployeeStatus.freelance).toList();

  List<AttendanceLog> logsOn(String employeeId, String date) =>
      attendance.where((a) => a.employeeId == employeeId && a.date == date).toList();

  List<AttendanceLog> todayLogsFor(String employeeId) => logsOn(employeeId, today);

  List<HrdApprovalRequest> get pendingApprovals =>
      approvals.where((r) => r.status == HrdApprovalStatus.menunggu).toList();

  bool isRoleNameTaken(String name, {String? excludingId}) {
    final wanted = name.trim().toLowerCase();
    return roles.any((r) => r.id != excludingId && r.name.toLowerCase() == wanted);
  }

  // ---- payroll -----------------------------------------------------------

  PayPeriod get currentMonthPeriod => PayPeriod.month(currentMonth);

  /// Period the Rekap Penggajian / Slip Gaji screens are currently on.
  PayPeriod get selectedPayrollPeriod => periodMode == PayrollPeriodMode.bulanan ? currentMonthPeriod : selectedWeek;

  String get selectedPayrollPeriodLabel => periodMode == PayrollPeriodMode.bulanan
      ? monthLabel(currentMonth)
      : '${formatDateShort(selectedWeek.start)} – ${formatDateLong(selectedWeek.end)}';

  PayrollResult payrollFor(Employee employee, PayPeriod period) {
    return computePayroll(
      employee: employee,
      logs: attendance,
      additions: additions,
      deductions: deductions,
      openingBalances: openingBalances,
      period: period,
      today: today,
    );
  }

  AttendanceSummary attendanceFor(Employee employee, PayPeriod period) {
    return computeAttendance(employee, attendance, period, today);
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

final hrdControllerProvider = StateNotifierProvider<HrdController, HrdState>((ref) => HrdController());

/// Owns every HRD business rule so none of them live in widgets
/// (AGENTS.md: business logic independent of UI). All state is in-memory
/// placeholder data.
class HrdController extends StateNotifier<HrdState> {
  final DateTime Function() _clock;
  int _nextId = 5000;

  HrdController({DateTime Function()? clock, HrdState? initial})
      : _clock = clock ?? DateTime.now,
        super(initial ?? HrdState.seed());

  String _newId(String prefix) => '$prefix-${++_nextId}';

  /// `<placeholder today> HH:mm` — same stamp shape the mockup writes.
  String _stamp() {
    final now = _clock();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '${state.today} $hh:$mm';
  }

  // ---- period mode (Rekap Penggajian + Slip Gaji) ------------------------

  void setPeriodMode(PayrollPeriodMode mode) => state = state.copyWith(periodMode: mode);

  void moveWeek(int deltaDays) => state = state.copyWith(selectedWeek: shiftWeek(state.selectedWeek, deltaDays));

  // ---- roles -------------------------------------------------------------

  HrdActionResult addRole(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return const HrdActionResult.failure('Nama role harus diisi');
    if (state.isRoleNameTaken(name)) return const HrdActionResult.failure('Role dengan nama ini sudah ada');
    final id = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
    state = state.copyWith(roles: [...state.roles, HrdRole(id: id, name: name)]);
    return HrdActionResult.success('Role "$name" ditambahkan');
  }

  HrdActionResult removeRole(String roleId) {
    final role = state.roleById(roleId);
    if (role == null) return const HrdActionResult.failure('Role tidak ditemukan');
    // The UI never shows a delete control for locked roles; this is the
    // safety net behind it (Manajer is a fixed permission level).
    if (role.locked) return const HrdActionResult.failure('Role terkunci tidak bisa dihapus');
    final inUse = state.employees.any((e) => e.role == role.name);
    if (inUse) return const HrdActionResult.failure('Role masih dipakai karyawan, tidak bisa dihapus');
    state = state.copyWith(roles: state.roles.where((r) => r.id != roleId).toList());
    return HrdActionResult.success('Role "${role.name}" dihapus');
  }

  // ---- employees ---------------------------------------------------------

  HrdActionResult saveEmployee({
    String? editingId,
    required String name,
    required String phone,
    required String address,
    required String role,
    required EmployeeStatus status,
    String? resignDate,
    required String startDate,
    required String wagePerHourText,
    required String bonusFullTimeText,
    required String overtimeRateText,
  }) {
    if (name.trim().isEmpty) return const HrdActionResult.failure('Nama wajib diisi');
    if (wagePerHourText.trim().isEmpty) return const HrdActionResult.failure('Upah per jam wajib diisi');

    final wage = int.tryParse(wagePerHourText.trim()) ?? 0;
    final bonus = int.tryParse(bonusFullTimeText.trim()) ?? 0;
    final parsedRate = int.tryParse(overtimeRateText.trim()) ?? 0;
    final rate = parsedRate > 0 ? parsedRate : defaultOvertimeRatePer30Min;
    final effectiveResignDate = status == EmployeeStatus.resign ? ((resignDate?.isNotEmpty ?? false) ? resignDate : state.today) : null;

    if (editingId != null) {
      final existing = state.employeeById(editingId);
      if (existing == null) return const HrdActionResult.failure('Karyawan tidak ditemukan');
      final updated = existing.copyWith(
        name: name.trim(),
        phone: phone,
        address: address,
        role: role,
        status: status,
        resignDate: effectiveResignDate,
        clearResignDate: effectiveResignDate == null,
        startDate: startDate,
        wagePerHour: wage,
        bonusFullTime: bonus,
        overtimeRatePer30Min: rate,
      );
      state = state.copyWith(employees: state.employees.map((e) => e.id == editingId ? updated : e).toList());
      return HrdActionResult.success('Perubahan disimpan', savedId: editingId);
    }

    final id = _newId('EMP');
    state = state.copyWith(
      employees: [
        ...state.employees,
        Employee(
          id: id,
          name: name.trim(),
          phone: phone,
          address: address,
          status: status,
          resignDate: effectiveResignDate,
          role: role,
          wagePerHour: wage,
          bonusFullTime: bonus,
          overtimeRatePer30Min: rate,
          startDate: startDate,
        ),
      ],
    );
    return HrdActionResult.success('Karyawan baru ditambahkan', savedId: id);
  }

  // ---- attendance (Koreksi Absen) ---------------------------------------

  /// Directly edits (or creates / clears) today's Masuk and Pulang rows —
  /// the "employee worked but forgot to clock in" case. Updates existing
  /// rows in place, never duplicates.
  ///
  /// Guard (repository-level, not just UI): a normal `pulang` can NOT be
  /// saved while the employee is stuck mid-bolong (bolong with no
  /// masuk_lagi after it). Resolve it via Approval first.
  HrdActionResult saveMasukPulang(String employeeId, String masukRaw, String pulangRaw) {
    final masukInput = masukRaw.trim();
    final pulangInput = pulangRaw.trim();
    final masuk = masukInput.isEmpty ? null : normalizeTimeInput(masukInput);
    final pulang = pulangInput.isEmpty ? null : normalizeTimeInput(pulangInput);
    if (masukInput.isNotEmpty && masuk == null) return const HrdActionResult.failure('Format Jam Masuk salah, contoh: 09:00');
    if (pulangInput.isNotEmpty && pulang == null) return const HrdActionResult.failure('Format Jam Pulang salah, contoh: 19:00');

    final date = state.today;
    if (pulang != null) {
      final hypothetical = state.logsOn(employeeId, date).where((l) => l.type != AttendanceLogType.masuk).toList();
      if (masuk != null) {
        hypothetical.add(AttendanceLog(id: 'hypothetical', employeeId: employeeId, date: date, type: AttendanceLogType.masuk, time: masuk));
      }
      if (findStuckBolong(hypothetical) != null) {
        return const HrdActionResult.failure('Karyawan masih bolong (belum masuk lagi) — selesaikan lewat Approval dulu');
      }
    }

    var logs = _upsertLog(state.attendance, employeeId, date, AttendanceLogType.masuk, masuk);
    logs = _upsertLog(logs, employeeId, date, AttendanceLogType.pulang, pulang);
    state = state.copyWith(attendance: logs);
    _syncClarification(employeeId, date);
    return const HrdActionResult.success('Jam masuk & pulang disimpan');
  }

  /// Adds an extra note (Masuk Lagi / Jam Bolong / Libur) to today.
  HrdActionResult addCorrection(String employeeId, AttendanceLogType type, String timeRaw) {
    String? time;
    if (type != AttendanceLogType.libur) {
      time = normalizeTimeInput(timeRaw);
      if (time == null) return const HrdActionResult.failure('Format jam salah, contoh: 09:00');
    }
    final date = state.today;
    state = state.copyWith(
      attendance: [
        ...state.attendance,
        AttendanceLog(id: _newId('c'), employeeId: employeeId, date: date, type: type, time: time),
      ],
    );
    _syncClarification(employeeId, date);
    return const HrdActionResult.success('Koreksi disimpan');
  }

  List<AttendanceLog> _upsertLog(
    List<AttendanceLog> logs,
    String employeeId,
    String date,
    AttendanceLogType type,
    String? time,
  ) {
    final index = logs.indexWhere((a) => a.employeeId == employeeId && a.date == date && a.type == type);
    if (time == null || time.isEmpty) {
      if (index == -1) return logs;
      return [...logs]..removeAt(index);
    }
    if (index != -1) {
      final copy = [...logs];
      copy[index] = copy[index].copyWith(time: time);
      return copy;
    }
    return [...logs, AttendanceLog(id: _newId('c'), employeeId: employeeId, date: date, type: type, time: time)];
  }

  /// Keeps the attendance-clarification approval queue in sync with the
  /// real log state for one employee/day: opens a request the moment a
  /// stuck bolong appears, and auto-closes it if the stuck state has gone
  /// away by any other route — no "ghost" requests.
  void _syncClarification(String employeeId, String date) {
    final dayLogs = state.logsOn(employeeId, date);
    final hasMasuk = dayLogs.any((l) => l.type == AttendanceLogType.masuk);
    final stuck = hasMasuk ? findStuckBolong(dayLogs) : null;

    final openIndex = state.approvals.indexWhere(
      (r) =>
          r.type == HrdApprovalType.attendanceClarification &&
          r.employeeId == employeeId &&
          r.date == date &&
          r.status == HrdApprovalStatus.menunggu,
    );

    if (stuck != null && openIndex == -1) {
      state = state.copyWith(
        approvals: [
          ...state.approvals,
          HrdApprovalRequest(
            id: _newId('req'),
            type: HrdApprovalType.attendanceClarification,
            employeeId: employeeId,
            date: date,
            status: HrdApprovalStatus.menunggu,
            bolongTime: stuck.time,
          ),
        ],
      );
    } else if (stuck == null && openIndex != -1) {
      final stamp = _stamp();
      final updated = [...state.approvals];
      updated[openIndex] = updated[openIndex].copyWith(
        status: HrdApprovalStatus.disetujui,
        decidedBy: 'Sistem',
        decidedAt: stamp,
        resolution: 'auto_resolved',
      );
      state = state.copyWith(approvals: updated);
    }
  }

  // ---- approvals ---------------------------------------------------------

  HrdApprovalRequest? _requestById(String id) {
    for (final r in state.approvals) {
      if (r.id == id) return r;
    }
    return null;
  }

  void _replaceRequest(HrdApprovalRequest updated) {
    state = state.copyWith(approvals: state.approvals.map((r) => r.id == updated.id ? updated : r).toList());
  }

  /// Approve/reject a staff income request. Approving copies it into
  /// payroll additions; either way the original request stays as the
  /// audit record. A processed request can never be processed twice.
  HrdActionResult decideIncomeRequest(String requestId, {required bool approve}) {
    final req = _requestById(requestId);
    if (req == null || req.type != HrdApprovalType.income) return const HrdActionResult.failure('Pengajuan tidak ditemukan');
    if (req.status != HrdApprovalStatus.menunggu) return const HrdActionResult.failure('Pengajuan sudah diproses');

    final stamp = _stamp();
    _replaceRequest(
      req.copyWith(
        status: approve ? HrdApprovalStatus.disetujui : HrdApprovalStatus.ditolak,
        decidedBy: 'Owner',
        decidedAt: stamp,
      ),
    );
    if (approve) {
      state = state.copyWith(
        additions: [
          ...state.additions,
          PayrollAddition(
            id: _newId('add'),
            employeeId: req.employeeId,
            label: req.label ?? '',
            amount: req.amount ?? 0,
            date: req.date,
            category: 'Tambahan',
            source: PayrollSource.staff,
            approvedBy: 'Owner',
            approvedAt: stamp,
          ),
        ],
      );
    }
    return HrdActionResult.success(approve ? 'Pengajuan disetujui' : 'Pengajuan ditolak');
  }

  /// Option A: the employee actually came back — fill in the real
  /// `masuk_lagi`, closing the gap. It must be later than the bolong, or
  /// the employee would still be "stuck" and the case would just reopen.
  HrdActionResult clarifyWithMasukLagi(String requestId, String timeRaw) {
    final req = _requestById(requestId);
    if (req == null || req.type != HrdApprovalType.attendanceClarification) {
      return const HrdActionResult.failure('Pengajuan tidak ditemukan');
    }
    if (req.status != HrdApprovalStatus.menunggu) return const HrdActionResult.failure('Pengajuan sudah diproses');

    final time = normalizeTimeInput(timeRaw);
    if (time == null) return const HrdActionResult.failure('Format jam salah, contoh: 14:00');

    final stuck = findStuckBolong(state.logsOn(req.employeeId, req.date));
    if (stuck != null && timeToMinutes(time) <= timeToMinutes(stuck.time!)) {
      return HrdActionResult.failure('Jam masuk lagi harus setelah jam bolong (${stuck.time})');
    }

    state = state.copyWith(attendance: _upsertLog(state.attendance, req.employeeId, req.date, AttendanceLogType.masukLagi, time));
    _replaceRequest(req.copyWith(status: HrdApprovalStatus.disetujui, decidedBy: 'Owner', decidedAt: _stamp(), resolution: 'masuk_lagi:$time'));
    _syncClarification(req.employeeId, req.date);
    return HrdActionResult.success('Masuk lagi jam $time disimpan');
  }

  /// Option B: the employee is not coming back — the bolong time IS the
  /// day's clock-out.
  ///
  /// The unresolved `bolong` row is CONVERTED into the `pulang` row (same
  /// time), not left beside a new `pulang`. Leaving the bolong in place
  /// keeps the day "stuck", so the day never resolves and the sync step
  /// re-opens an identical request — which is exactly what the original
  /// mockup did (found by running its engine; see the golden test).
  HrdActionResult clarifyAsPulang(String requestId) {
    final req = _requestById(requestId);
    if (req == null || req.type != HrdApprovalType.attendanceClarification) {
      return const HrdActionResult.failure('Pengajuan tidak ditemukan');
    }
    if (req.status != HrdApprovalStatus.menunggu) return const HrdActionResult.failure('Pengajuan sudah diproses');

    final stuck = findStuckBolong(state.logsOn(req.employeeId, req.date));
    if (stuck == null) {
      // Already resolved some other way — just close the stale request.
      _syncClarification(req.employeeId, req.date);
      return const HrdActionResult.failure('Kasus ini sudah tidak perlu klarifikasi');
    }

    final time = stuck.time!;
    final withoutStuck = state.attendance.where((l) => l.id != stuck.id).toList();
    state = state.copyWith(attendance: _upsertLog(withoutStuck, req.employeeId, req.date, AttendanceLogType.pulang, time));
    _replaceRequest(req.copyWith(status: HrdApprovalStatus.disetujui, decidedBy: 'Owner', decidedAt: _stamp(), resolution: 'pulang:$time'));
    _syncClarification(req.employeeId, req.date);
    return HrdActionResult.success('Jam $time ditetapkan sebagai jam pulang');
  }

  // ---- payroll items -----------------------------------------------------

  /// Owner-entered addition/deduction: always effective immediately (no
  /// pending state on this path — unlike staff income requests).
  HrdActionResult addPayrollItem({
    required String employeeId,
    required bool isAddition,
    required String category,
    required String amountText,
    required String date,
    required String note,
  }) {
    final amount = int.tryParse(amountText.trim()) ?? 0;
    if (amount <= 0) return const HrdActionResult.failure('Nominal harus diisi');
    final label = note.trim().isNotEmpty ? note.trim() : category;

    if (isAddition) {
      state = state.copyWith(
        additions: [
          ...state.additions,
          PayrollAddition(
            id: _newId('add'),
            employeeId: employeeId,
            label: label,
            amount: amount,
            date: date,
            category: category,
            source: PayrollSource.owner,
            approvedBy: 'Owner',
            approvedAt: _stamp(),
          ),
        ],
      );
      return const HrdActionResult.success('Penghasilan ditambahkan');
    }
    state = state.copyWith(
      deductions: [
        ...state.deductions,
        PayrollDeduction(id: _newId('ded'), employeeId: employeeId, label: label, amount: amount, date: date, category: category),
      ],
    );
    return const HrdActionResult.success('Potongan dicatat');
  }

  // ---- staff submissions -------------------------------------------------

  /// Staff pengeluaran is recorded immediately — NO approval.
  HrdActionResult submitStaffExpense({
    required String employeeId,
    required String category,
    required String amountText,
    required String date,
    required String note,
  }) {
    final amount = int.tryParse(amountText.trim()) ?? 0;
    if (amount <= 0) return const HrdActionResult.failure('Nominal harus diisi');
    state = state.copyWith(
      deductions: [
        ...state.deductions,
        PayrollDeduction(
          id: _newId('ded'),
          employeeId: employeeId,
          label: note.trim().isNotEmpty ? note.trim() : category,
          amount: amount,
          date: date,
          category: category,
        ),
      ],
    );
    return const HrdActionResult.success('Pengeluaran tercatat');
  }

  /// Staff pemasukan MUST wait for Owner/Manajer approval: it only enters
  /// payroll after [decideIncomeRequest] approves it.
  HrdActionResult submitStaffIncome({
    required String employeeId,
    required String category,
    required String amountText,
    required String date,
    required String note,
  }) {
    final amount = int.tryParse(amountText.trim()) ?? 0;
    if (amount <= 0) return const HrdActionResult.failure('Nominal harus diisi');
    state = state.copyWith(
      approvals: [
        ...state.approvals,
        HrdApprovalRequest(
          id: _newId('req'),
          type: HrdApprovalType.income,
          employeeId: employeeId,
          date: date,
          status: HrdApprovalStatus.menunggu,
          label: note.trim().isNotEmpty ? note.trim() : category,
          amount: amount,
          note: note,
        ),
      ],
    );
    return const HrdActionResult.success('Pengajuan terkirim, menunggu persetujuan');
  }
}

// ---------------------------------------------------------------------------
// Kelola Karyawan list filter (search / status / role / sort)
// ---------------------------------------------------------------------------

enum EmployeeSort { namaAz, namaZa, upahTertinggi, gabungTerbaru, gabungTerlama }

extension EmployeeSortLabel on EmployeeSort {
  String get label => switch (this) {
        EmployeeSort.namaAz => 'Nama A-Z',
        EmployeeSort.namaZa => 'Nama Z-A',
        EmployeeSort.upahTertinggi => 'Upah Tertinggi',
        EmployeeSort.gabungTerbaru => 'Gabung Terbaru',
        EmployeeSort.gabungTerlama => 'Gabung Terlama',
      };
}

class EmployeeListFilter {
  final String search;
  final EmployeeStatus? status; // null = Semua Status
  final String? role; // null = Semua Role
  final EmployeeSort sort;

  const EmployeeListFilter({this.search = '', this.status, this.role, this.sort = EmployeeSort.namaAz});

  EmployeeListFilter copyWith({
    String? search,
    EmployeeStatus? status,
    bool clearStatus = false,
    String? role,
    bool clearRole = false,
    EmployeeSort? sort,
  }) {
    return EmployeeListFilter(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      role: clearRole ? null : (role ?? this.role),
      sort: sort ?? this.sort,
    );
  }

  /// Filtered + sorted list. Ties keep their original order (stable),
  /// like the mockup's JS sort.
  List<Employee> apply(List<Employee> all) {
    final query = search.trim().toLowerCase();
    final filtered = <Employee>[];
    for (final e in all) {
      if (query.isNotEmpty && !e.name.toLowerCase().contains(query)) continue;
      if (status != null && e.status != status) continue;
      if (role != null && e.role != role) continue;
      filtered.add(e);
    }

    final indexed = List<int>.generate(filtered.length, (i) => i);
    int byName(int a, int b) => filtered[a].name.toLowerCase().compareTo(filtered[b].name.toLowerCase());
    indexed.sort((a, b) {
      final primary = switch (sort) {
        EmployeeSort.namaAz => byName(a, b),
        EmployeeSort.namaZa => byName(b, a),
        EmployeeSort.upahTertinggi => filtered[b].wagePerHour.compareTo(filtered[a].wagePerHour),
        EmployeeSort.gabungTerbaru => filtered[b].startDate.compareTo(filtered[a].startDate),
        EmployeeSort.gabungTerlama => filtered[a].startDate.compareTo(filtered[b].startDate),
      };
      return primary != 0 ? primary : a.compareTo(b);
    });
    return indexed.map((i) => filtered[i]).toList();
  }
}

class EmployeeListFilterController extends StateNotifier<EmployeeListFilter> {
  EmployeeListFilterController() : super(const EmployeeListFilter());

  void setSearch(String value) => state = state.copyWith(search: value);
  void setStatus(EmployeeStatus? value) => state = value == null ? state.copyWith(clearStatus: true) : state.copyWith(status: value);
  void setRole(String? value) => state = value == null ? state.copyWith(clearRole: true) : state.copyWith(role: value);
  void setSort(EmployeeSort value) => state = state.copyWith(sort: value);
}

final hrdEmployeeListFilterProvider =
    StateNotifierProvider<EmployeeListFilterController, EmployeeListFilter>((ref) => EmployeeListFilterController());
