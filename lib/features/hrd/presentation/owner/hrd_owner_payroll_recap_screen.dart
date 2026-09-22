import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import 'hrd_owner_payslip_screen.dart';
import 'hrd_owner_performance_recap_screen.dart';

/// Owner Screen 9 — Rekap Penggajian. Period mode (Bulanan/Mingguan) is
/// SHARED with Slip Gaji (see [HrdState.periodMode]/[HrdState.selectedWeek]).
class HrdOwnerPayrollRecapScreen extends ConsumerWidget {
  const HrdOwnerPayrollRecapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final controller = ref.read(hrdControllerProvider.notifier);
    final period = state.selectedPayrollPeriod;

    final rows = state.employees.map((e) => (employee: e, payroll: state.payrollFor(e, period))).toList();
    final totalNet = rows.fold<int>(0, (sum, r) => sum + r.payroll.netPay);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Rekap Penggajian')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  _PeriodModeToggle(
                    mode: state.periodMode,
                    label: state.selectedPayrollPeriodLabel,
                    onModeChanged: controller.setPeriodMode,
                    onShiftWeek: controller.moveWeek,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    backgroundColor: AppColors.brand,
                    borderColor: AppColors.brand,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Gaji Bersih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(height: 4),
                        Text(formatRupiah(totalNet), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final row in rows) ...[
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: InkWell(
                        onTap: () => AppNav.push(context, (_) => HrdOwnerPayslipScreen(employeeId: row.employee.id)),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
                          child: Row(
                            children: [
                              AppItemThumbnail(name: row.employee.name, size: 44, radius: AppRadius.pill),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(row.employee.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                        Text(formatRupiah(row.payroll.netPay), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${row.employee.role} · ${row.payroll.attendance.hadirDays} hari hadir', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppButton.secondary(
                    label: 'Rekap Kinerja',
                    icon: Icons.trending_up_rounded,
                    fullWidth: true,
                    onPressed: () => AppNav.push(context, (_) => const HrdOwnerPerformanceRecapScreen()),
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

class _PeriodModeToggle extends StatelessWidget {
  final PayrollPeriodMode mode;
  final String label;
  final ValueChanged<PayrollPeriodMode> onModeChanged;
  final ValueChanged<int> onShiftWeek;

  const _PeriodModeToggle({required this.mode, required this.label, required this.onModeChanged, required this.onShiftWeek});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Expanded(child: _SegmentButton(label: 'Bulanan', selected: mode == PayrollPeriodMode.bulanan, onTap: () => onModeChanged(PayrollPeriodMode.bulanan))),
              Expanded(child: _SegmentButton(label: 'Mingguan', selected: mode == PayrollPeriodMode.mingguan, onTap: () => onModeChanged(PayrollPeriodMode.mingguan))),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (mode == PayrollPeriodMode.mingguan)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconButton.standard(icon: Icons.chevron_left_rounded, onTap: () => onShiftWeek(-7)),
              Expanded(
                child: Column(
                  children: [
                    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const Text('Gajian tiap Jumat', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              AppIconButton.standard(icon: Icons.chevron_right_rounded, onTap: () => onShiftWeek(7)),
            ],
          )
        else
          Align(alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? AppColors.brand : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.pill)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
