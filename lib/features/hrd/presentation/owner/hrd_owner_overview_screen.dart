import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import 'hrd_owner_approval_screen.dart';
import 'hrd_owner_attendance_today_screen.dart';
import 'hrd_owner_employee_list_screen.dart';
import 'hrd_owner_payroll_recap_screen.dart';

/// Owner Screen 1 — Overview. Reached from the "Staff" swipe-up tile for
/// an Owner-mode session. Per the migration prompt this screen shows the
/// month's total wage (incl. bonus & overtime), a 4-stat breakdown, and 3
/// nav buttons in this exact order: Rekap Penggajian → Kehadiran Hari Ini
/// → Kelola Karyawan (no "Tambah Karyawan" button here — that only lives
/// inside Kelola Karyawan).
class HrdOwnerOverviewScreen extends ConsumerWidget {
  const HrdOwnerOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final period = state.currentMonthPeriod;

    var totalWage = 0, totalBonus = 0, totalOvertime = 0, totalDeductions = 0;
    for (final e in state.employees) {
      final p = state.payrollFor(e, period);
      totalWage += p.attendance.wagePay;
      totalBonus += p.attendance.fullTimeBonusPay + p.additionsTotal;
      totalOvertime += p.attendance.overtimePay;
      totalDeductions += p.deductionsTotal;
    }
    final totalUpah = totalWage + totalBonus + totalOvertime;
    final pendingCount = state.pendingApprovals.length;
    final activeCount = state.activeEmployees.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Karyawan')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text(monthLabel(state.currentMonth), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text('$activeCount/${state.employees.length} Karyawan Aktif', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.lg),
                  AppCardShell(
                    backgroundColor: AppColors.brand,
                    borderColor: AppColors.brand,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Upah Bulan Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
                        const SizedBox(height: 4),
                        Text(formatRupiah(totalUpah), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Termasuk bonus & lembur', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _OverviewStat(label: 'Gaji Pokok', value: totalWage, icon: Icons.payments_rounded, color: AppColors.info)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _OverviewStat(label: 'Bonus', value: totalBonus, icon: Icons.card_giftcard_rounded, color: AppColors.tileStaff)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: _OverviewStat(label: 'Lembur', value: totalOvertime, icon: Icons.schedule_rounded, color: AppColors.tileHpp)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _OverviewStat(label: 'Potongan', value: totalDeductions, icon: Icons.remove_circle_rounded, color: AppColors.danger)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _NavButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Rekap Penggajian',
                    onTap: () => AppNav.push(context, (_) => const HrdOwnerPayrollRecapScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _NavButton(
                    icon: Icons.event_available_rounded,
                    label: 'Kehadiran Hari Ini',
                    onTap: () => AppNav.push(context, (_) => const HrdOwnerAttendanceTodayScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _NavButton(
                    icon: Icons.groups_rounded,
                    label: 'Kelola Karyawan',
                    onTap: () => AppNav.push(context, (_) => const HrdOwnerEmployeeListScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _NavButton(
                    icon: Icons.fact_check_rounded,
                    label: 'Approval',
                    badgeCount: pendingCount,
                    onTap: () => AppNav.push(context, (_) => const HrdOwnerApprovalScreen()),
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

class _OverviewStat extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _OverviewStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary))),
            ],
          ),
          const SizedBox(height: 6),
          Text(formatRupiah(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavButton({required this.icon, required this.label, required this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18, color: AppColors.textPrimary),
            label: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$badgeCount', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}
