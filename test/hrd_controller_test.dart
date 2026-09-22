// Tests for HrdController's attendance-clarification flow.
//
// simA in the golden-value session (running the ORIGINAL mockup JS
// directly) showed the mockup's own naive port has a latent bug: after
// "Option B" (treat bolong as pulang), it left the stuck `bolong` row in
// place next to a new `pulang` row, so the day never actually stopped
// being "stuck" — the approval request re-opened. clarifyAsPulang() here
// deliberately fixes that by converting the bolong row into the pulang
// row instead of adding a second row. These tests lock in the FIXED
// behavior, not the mockup's original bug.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/features/hrd/application/hrd_provider.dart';
import 'package:mamam_kasir/features/hrd/domain/hrd_models.dart';
import 'package:mamam_kasir/features/hrd/domain/payroll_engine.dart';

void main() {
  group('attendance clarification (Option A / Option B)', () {
    late HrdController controller;
    const employeeId = 'EMP-1002';
    const date = '2026-09-11'; // must equal kHrdPlaceholderToday for the seed set

    setUp(() {
      controller = HrdController();
      // Put EMP-1002 into a "stuck" state today: masuk, then an
      // unresolved bolong, mirroring simA's setup.
      controller.saveMasukPulang(employeeId, '09:00', '');
      controller.addCorrection(employeeId, AttendanceLogType.bolong, '12:00');
    });

    test('stuck bolong auto-opens an attendance clarification request', () {
      final open = controller.state.pendingApprovals.where((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId);
      expect(open.length, 1);
      expect(open.first.bolongTime, '12:00');
    });

    test('a normal pulang is refused while stuck (guard)', () {
      final result = controller.saveMasukPulang(employeeId, '09:00', '19:00');
      expect(result.ok, false);
    });

    test('Option B closes the request AND resolves the day (fixes the mockup bug)', () {
      final reqId = controller.state.pendingApprovals.firstWhere((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId).id;

      final result = controller.clarifyAsPulang(reqId);
      expect(result.ok, true);

      final stillOpen = controller.state.pendingApprovals.where((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId);
      expect(stillOpen.length, 0, reason: 'the request must close, unlike the original mockup port');

      final dayLogs = controller.state.logsOn(employeeId, date);
      expect(findStuckBolong(dayLogs), isNull);

      final employee = controller.state.employeeById(employeeId)!;
      final dayResult = computeDayResult(dayLogs, employee, date, controller.state.today);
      expect(dayResult.status, DayStatus.hadir, reason: 'the day must resolve to hadir, not stay perlu_klarifikasi');

      // The bolong row was converted into pulang@12:00, not duplicated.
      expect(dayLogs.where((l) => l.type == AttendanceLogType.bolong), isEmpty);
      expect(dayLogs.where((l) => l.type == AttendanceLogType.pulang).single.time, '12:00');
    });

    test('Option A requires a masuk_lagi strictly after the bolong time', () {
      final reqId = controller.state.pendingApprovals.firstWhere((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId).id;

      final tooEarly = controller.clarifyWithMasukLagi(reqId, '11:00');
      expect(tooEarly.ok, false);

      final ok = controller.clarifyWithMasukLagi(reqId, '13:30');
      expect(ok.ok, true);

      final stillOpen = controller.state.pendingApprovals.where((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId);
      expect(stillOpen.length, 0);
      expect(findStuckBolong(controller.state.logsOn(employeeId, date)), isNull);
    });

    test('fixing the stuck state through a direct correction auto-closes the request (no ghost requests)', () {
      controller.addCorrection(employeeId, AttendanceLogType.masukLagi, '13:00');
      final stillOpen = controller.state.pendingApprovals.where((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId);
      expect(stillOpen.length, 0);
    });

    test('a processed request can never be processed twice', () {
      final reqId = controller.state.pendingApprovals.firstWhere((r) => r.type == HrdApprovalType.attendanceClarification && r.employeeId == employeeId).id;
      final first = controller.clarifyAsPulang(reqId);
      expect(first.ok, true);
      final second = controller.clarifyAsPulang(reqId);
      expect(second.ok, false);
    });
  });

  group('staff income approval', () {
    test('approving copies the request into payroll additions; rejecting does not', () {
      final approveController = HrdController();
      final before = approveController.state.additions.length;
      approveController.submitStaffIncome(employeeId: 'EMP-1002', category: 'Ongkir', amountText: '40000', date: '2026-09-11', note: 'Ongkir antar');
      final req = approveController.state.pendingApprovals.firstWhere((r) => r.type == HrdApprovalType.income);
      final approved = approveController.decideIncomeRequest(req.id, approve: true);
      expect(approved.ok, true);
      expect(approveController.state.additions.length, before + 1);

      final rejectController = HrdController();
      final beforeReject = rejectController.state.additions.length;
      rejectController.submitStaffIncome(employeeId: 'EMP-1002', category: 'Ongkir', amountText: '40000', date: '2026-09-11', note: 'Ongkir antar');
      final rejectReq = rejectController.state.pendingApprovals.firstWhere((r) => r.type == HrdApprovalType.income);
      final rejected = rejectController.decideIncomeRequest(rejectReq.id, approve: false);
      expect(rejected.ok, true);
      expect(rejectController.state.additions.length, beforeReject, reason: 'a rejected request must not add to payroll');
    });

    test('staff expense is recorded immediately with no approval step', () {
      final controller = HrdController();
      final beforeCount = controller.state.deductions.length;
      final beforePending = controller.state.pendingApprovals.length;
      controller.submitStaffExpense(employeeId: 'EMP-1002', category: 'Kasbon', amountText: '20000', date: '2026-09-11', note: '');
      expect(controller.state.deductions.length, beforeCount + 1);
      expect(controller.state.pendingApprovals.length, beforePending, reason: 'expenses never create an approval request');
    });
  });
}
