import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../application/hrd_staff_session_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../widgets/hrd_shared_widgets.dart';
import 'hrd_staff_dashboard_screen.dart';

/// Staff Screen 4 — Detail Gaji / Slip: full breakdown for the current
/// session's employee only.
class HrdStaffPayslipScreen extends ConsumerWidget {
  const HrdStaffPayslipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(hrdStaffSessionProvider);
    final state = ref.watch(hrdControllerProvider);
    final e = session.employeeId != null ? state.employeeById(session.employeeId!) : null;
    if (e == null) return const _Expired();

    final payroll = state.payrollFor(e, state.currentMonthPeriod);
    final att = payroll.attendance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Detail Gaji')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text(monthLabel(state.currentMonth), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        HrdDetailRow('Upah Jam Kerja (${att.totalWorkedHours.toStringAsFixed(1)} jam)', formatRupiah(att.wagePay)),
                        HrdDetailRow('Bonus Full Time (${att.fullTimeDays} hari)', formatRupiah(att.fullTimeBonusPay)),
                        HrdDetailRow('Uang Lembur (${att.overtimeBlocks30Min} blok)', formatRupiah(att.overtimePay)),
                        for (final a in payroll.additions) HrdDetailRow(a.label, formatRupiah(a.amount)),
                        const Divider(height: AppSpacing.lg, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Penghasilan', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(formatRupiah(payroll.totalPenghasilan), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: payroll.deductions.isEmpty
                        ? const Text('Tidak ada potongan', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
                        : Column(children: [for (final d in payroll.deductions) HrdDetailRow(d.label, '-${formatRupiah(d.amount)}', valueColor: AppColors.danger)]),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    backgroundColor: AppColors.brand,
                    borderColor: AppColors.brand,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gaji Bersih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(height: 4),
                        Text(formatRupiah(payroll.netPay), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
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

class _Expired extends StatelessWidget {
  const _Expired();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Detail Gaji')),
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HrdStaffDashboardScreen()), (r) => false),
                  child: const Text('Sesi berakhir — kembali'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
