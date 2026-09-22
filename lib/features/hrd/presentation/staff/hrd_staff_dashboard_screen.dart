import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../application/hrd_staff_session_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';
import '../../domain/payroll_engine.dart';
import '../widgets/hrd_shared_widgets.dart';
import 'hrd_staff_add_expense_screen.dart';
import 'hrd_staff_add_income_screen.dart';
import 'hrd_staff_entry_screen.dart';
import 'hrd_staff_history_screen.dart';
import 'hrd_staff_income_status_screen.dart';
import 'hrd_staff_payslip_screen.dart';

/// Staff Screen 3 — Dashboard. [StaffSession] is the only source of "who
/// am I" — this screen never lets the viewer pick a different employee.
class HrdStaffDashboardScreen extends ConsumerWidget {
  const HrdStaffDashboardScreen({super.key});

  void _logout(BuildContext context, WidgetRef ref) {
    ref.read(hrdStaffSessionProvider.notifier).logout();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HrdStaffEntryScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(hrdStaffSessionProvider);
    final state = ref.watch(hrdControllerProvider);
    final Employee? e = session.employeeId != null ? state.employeeById(session.employeeId!) : null;

    if (e == null) return _SessionExpired(onBack: () => _logout(context, ref));

    final payroll = state.payrollFor(e, state.currentMonthPeriod);
    final todayStat = todayStatus(state.todayLogsFor(e.id), e, state.today);
    final onShift = isOnShiftNow(state.todayLogsFor(e.id));
    final pendingCount = state.approvals.where((r) => r.type == HrdApprovalType.income && r.employeeId == e.id && r.status == HrdApprovalStatus.menunggu).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(title: const Text('Karyawan'), trailingIcon: Icons.logout_rounded, onTrailingTap: () => _logout(context, ref)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text('Halo, ${e.name.split(' ').first}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(e.role, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status Hari Ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        dayStatusBadge(todayStat, onShift: onShift),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCardShell(
                    backgroundColor: AppColors.brand,
                    borderColor: AppColors.brand,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gaji Bulan Ini · ${monthLabel(state.currentMonth)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(height: 6),
                        Text(formatRupiah(payroll.netPay), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => AppNav.push(context, (_) => const HrdStaffPayslipScreen()),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              foregroundColor: Colors.white,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                            ),
                            child: const Text('Lihat Detail Gaji', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const HrdSectionLabel('PENGHASILAN'),
                  AppCardShell(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        HrdDetailRow('Upah Jam Kerja', formatRupiah(payroll.attendance.wagePay)),
                        if (payroll.attendance.fullTimeBonusPay > 0) HrdDetailRow('Bonus Full Time', formatRupiah(payroll.attendance.fullTimeBonusPay)),
                        if (payroll.attendance.overtimePay > 0) HrdDetailRow('Uang Lembur', formatRupiah(payroll.attendance.overtimePay)),
                        if (payroll.additionsTotal > 0) HrdDetailRow('Tambahan', formatRupiah(payroll.additionsTotal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const HrdSectionLabel('POTONGAN'),
                  AppCardShell(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                        Text('-${formatRupiah(payroll.deductionsTotal)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: AppButton.primary(label: '+ Pemasukan', fullWidth: true, onPressed: () => AppNav.push(context, (_) => HrdStaffAddIncomeScreen(employeeId: e.id)))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: AppButton.secondary(label: '+ Pengeluaran', fullWidth: true, onPressed: () => AppNav.push(context, (_) => HrdStaffAddExpenseScreen(employeeId: e.id)))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AppButton.secondary(
                        label: 'Status Pengajuan',
                        icon: Icons.receipt_long_rounded,
                        fullWidth: true,
                        onPressed: () => AppNav.push(context, (_) => HrdStaffIncomeStatusScreen(employeeId: e.id)),
                      ),
                      if (pendingCount > 0)
                        Positioned(
                          top: -6,
                          right: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('$pendingCount', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.secondary(
                    label: 'Riwayat',
                    icon: Icons.history_rounded,
                    fullWidth: true,
                    onPressed: () => AppNav.push(context, (_) => HrdStaffHistoryScreen(employeeId: e.id)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionExpired extends StatelessWidget {
  final VoidCallback onBack;
  const _SessionExpired({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Karyawan')),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppEmptyState(icon: Icons.info_outline_rounded, title: 'Sesi berakhir, silakan pilih nama & masukkan PIN kembali.'),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.primary(label: 'Kembali', fullWidth: true, onPressed: onBack),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
