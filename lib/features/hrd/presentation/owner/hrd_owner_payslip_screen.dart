import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../widgets/hrd_shared_widgets.dart';

/// Owner Screen 11 — Slip Gaji. Period toggle is SHARED with Rekap
/// Penggajian (see [HrdState.periodMode]). Cetak/PDF are placeholders —
/// not implemented at this stage per the migration prompt.
class HrdOwnerPayslipScreen extends ConsumerWidget {
  final String employeeId;
  const HrdOwnerPayslipScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final controller = ref.read(hrdControllerProvider.notifier);
    final e = state.employeeById(employeeId);
    if (e == null) {
      return Scaffold(body: SafeArea(child: Column(children: [const IosPageHeader(title: Text('Slip Gaji')), Expanded(child: Center(child: Text('Karyawan tidak ditemukan')))])));
    }

    final period = state.selectedPayrollPeriod;
    final payroll = state.payrollFor(e, period);
    final att = payroll.attendance;

    void showNotYetAvailable(String feature) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature — belum tersedia di prototype')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(title: const Text('Slip Gaji'), trailingIcon: Icons.share_rounded, onTrailingTap: () => showNotYetAvailable('Fitur bagikan')),
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
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        AppItemThumbnail(name: e.name, size: 56, radius: AppRadius.pill),
                        const SizedBox(height: AppSpacing.sm),
                        Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('${e.role} · ${state.selectedPayrollPeriodLabel}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HrdSectionLabel('PENGHASILAN'),
                        HrdDetailRow('Upah Jam Kerja (${att.totalWorkedHours.toStringAsFixed(1)} jam)', formatRupiah(att.wagePay)),
                        HrdDetailRow('Bonus Full Time (${att.fullTimeDays} hari)', formatRupiah(att.fullTimeBonusPay)),
                        HrdDetailRow('Uang Lembur (${att.overtimeBlocks30Min} blok)', formatRupiah(att.overtimePay)),
                        for (final a in payroll.additions) HrdDetailRow(a.label, formatRupiah(a.amount)),
                        const Divider(height: AppSpacing.lg, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Penghasilan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(formatRupiah(payroll.totalPenghasilan), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HrdSectionLabel('POTONGAN'),
                        if (payroll.deductions.isEmpty)
                          const Text('Tidak ada potongan', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
                        else
                          for (final d in payroll.deductions) HrdDetailRow(d.label, '-${formatRupiah(d.amount)}', valueColor: AppColors.danger),
                        if (payroll.openingBalance != 0) HrdDetailRow('Saldo Awal Bulan', formatRupiah(-payroll.openingBalance)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    backgroundColor: AppColors.brand,
                    borderColor: AppColors.brand,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gaji Bersih Diterima', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(height: 4),
                        Text(formatRupiah(payroll.netPay), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: AppButton.secondary(label: 'Cetak', icon: Icons.print_rounded, fullWidth: true, onPressed: () => showNotYetAvailable('Cetak PDF'))),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: AppButton.secondary(label: 'PDF', icon: Icons.picture_as_pdf_rounded, fullWidth: true, onPressed: () => showNotYetAvailable('Ekspor PDF'))),
                    ],
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
              Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              AppIconButton.standard(icon: Icons.chevron_right_rounded, onTap: () => onShiftWeek(7)),
            ],
          ),
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
