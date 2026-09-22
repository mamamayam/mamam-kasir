import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';
import '../../domain/payroll_engine.dart';
import '../widgets/hrd_shared_widgets.dart';
import 'hrd_owner_add_payroll_item_screen.dart';
import 'hrd_owner_attendance_history_screen.dart';
import 'hrd_owner_employee_form_screen.dart';
import 'hrd_owner_payslip_screen.dart';

/// Owner Screen 3 — Detail Karyawan: personal data, gaji & tarif, this
/// month's attendance summary (derived from Kehadiran), payroll
/// breakdown, and Edit / +Tambahan / +Potongan / Lihat Slip actions.
class HrdOwnerEmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;
  const HrdOwnerEmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final Employee? e = state.employeeById(employeeId);
    if (e == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const IosPageHeader(title: Text('Karyawan')),
              const Expanded(child: Center(child: Text('Karyawan tidak ditemukan'))),
            ],
          ),
        ),
      );
    }

    final period = state.currentMonthPeriod;
    final payroll = state.payrollFor(e, period);
    final att = payroll.attendance;
    final onShift = isOnShiftNow(state.todayLogsFor(e.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(
              title: Text(e.name),
              trailingIcon: Icons.more_horiz_rounded,
              onTrailingTap: () => AppNav.push(context, (_) => HrdOwnerEmployeeFormScreen(employeeId: e.id)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppItemThumbnail(name: e.name, size: 58, radius: AppRadius.pill),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(e.role, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                employeeStatusBadge(e.status),
                                if (onShift) const AppStatusBadge('Sedang Jaga', AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const HrdSectionLabel('DATA KARYAWAN'),
                  AppCardShell(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        HrdDetailRow('Nomor HP', e.phone.isEmpty ? '-' : e.phone),
                        HrdDetailRow('Alamat', e.address.isEmpty ? '-' : e.address),
                        HrdDetailRow('Mulai bekerja', formatDateLong(e.startDate)),
                        HrdDetailRow('Lama bekerja', tenureLabel(e.startDate, state.today)),
                        if (e.status == EmployeeStatus.resign) HrdDetailRow('Tanggal resign', e.resignDate != null ? formatDateLong(e.resignDate!) : '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const HrdSectionLabel('GAJI & TARIF'),
                  AppCardShell(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        HrdDetailRow('Upah per jam', formatRupiah(e.wagePerHour)),
                        HrdDetailRow('Bonus full time', formatRupiah(e.bonusFullTime)),
                        HrdDetailRow('Tarif lembur / 30 menit', formatRupiah(e.overtimeRatePer30Min)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HrdSectionLabel(monthLabel(state.currentMonth).toUpperCase()),
                  AppCardShell(
                    backgroundColor: AppColors.brand.withValues(alpha: 0.03),
                    borderColor: AppColors.brand.withValues(alpha: 0.12),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: AppColors.brand),
                            SizedBox(width: 4),
                            Text('Dari data Kehadiran', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brand)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: _MiniStat(value: '${att.hadirDays}', label: 'Hari Hadir')),
                            Expanded(child: _MiniStat(value: att.totalWorkedHours.toStringAsFixed(1), label: 'Jam Kerja')),
                            Expanded(
                              child: _MiniStat(
                                value: '${att.fullTimeDays}',
                                label: 'Hari Full Time',
                                color: att.overtimeBlocks30Min > 0 ? AppColors.warning : AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton.secondary(
                          label: 'Lihat Riwayat Kehadiran',
                          fullWidth: true,
                          onPressed: () => AppNav.push(context, (_) => HrdOwnerAttendanceHistoryScreen(employeeId: e.id)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCardShell(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        HrdDetailRow('Upah Jam Kerja', formatRupiah(att.wagePay)),
                        HrdDetailRow('Bonus Full Time', formatRupiah(att.fullTimeBonusPay)),
                        HrdDetailRow('Uang Lembur', formatRupiah(att.overtimePay)),
                        if (payroll.additionsTotal > 0) HrdDetailRow('Tambahan', formatRupiah(payroll.additionsTotal)),
                        if (payroll.deductionsTotal > 0) HrdDetailRow('Potongan', '-${formatRupiah(payroll.deductionsTotal)}', valueColor: AppColors.danger),
                        if (payroll.openingBalance != 0) HrdDetailRow('Saldo Awal Bulan', formatRupiah(-payroll.openingBalance)),
                        const Divider(height: AppSpacing.lg, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gaji Bersih', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            Text(formatRupiah(payroll.netPay), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.secondary(
                    label: 'Edit Karyawan',
                    icon: Icons.edit_rounded,
                    fullWidth: true,
                    onPressed: () => AppNav.push(context, (_) => HrdOwnerEmployeeFormScreen(employeeId: e.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.primary(
                          label: '+ Tambahan',
                          fullWidth: true,
                          onPressed: () => AppNav.push(context, (_) => HrdOwnerAddPayrollItemScreen(employeeId: e.id, isAddition: true)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton.secondary(
                          label: '+ Potongan',
                          fullWidth: true,
                          onPressed: () => AppNav.push(context, (_) => HrdOwnerAddPayrollItemScreen(employeeId: e.id, isAddition: false)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.secondary(
                    label: 'Lihat Slip Gaji',
                    icon: Icons.picture_as_pdf_rounded,
                    fullWidth: true,
                    onPressed: () => AppNav.push(context, (_) => HrdOwnerPayslipScreen(employeeId: e.id)),
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

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _MiniStat({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
}
