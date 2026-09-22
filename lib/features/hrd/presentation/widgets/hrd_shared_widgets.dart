import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';
import '../../domain/payroll_engine.dart';

Color statusColor(EmployeeStatus status) => switch (status) {
      EmployeeStatus.aktif => AppColors.success,
      EmployeeStatus.freelance => AppColors.warning,
      EmployeeStatus.cuti => AppColors.textSecondary,
      EmployeeStatus.resign => AppColors.danger,
    };

Widget employeeStatusBadge(EmployeeStatus status) => AppStatusBadge(status.label, statusColor(status));

String dayStatusLabel(DayStatus status, {required bool onShift}) => switch (status) {
      DayStatus.hadir => onShift ? 'Sedang Jaga' : 'Selesai',
      DayStatus.libur => 'Libur',
      DayStatus.perluKlarifikasi => 'Perlu Klarifikasi',
      DayStatus.belumPulang => 'Belum Pulang',
      DayStatus.belumAbsen => 'Belum Absen',
    };

Color dayStatusColor(DayStatus status, {required bool onShift}) => switch (status) {
      DayStatus.hadir => AppColors.success,
      DayStatus.libur => AppColors.textSecondary,
      DayStatus.perluKlarifikasi => AppColors.warning,
      DayStatus.belumPulang => AppColors.warning,
      DayStatus.belumAbsen => AppColors.textSecondary,
    };

Widget dayStatusBadge(DayStatus status, {required bool onShift}) =>
    AppStatusBadge(dayStatusLabel(status, onShift: onShift), dayStatusColor(status, onShift: onShift));

/// Label + value row used across Detail Karyawan, Slip Gaji, etc.
class HrdDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const HrdDetailRow(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class HrdSectionLabel extends StatelessWidget {
  final String text;
  const HrdSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
    );
  }
}

/// Employee row for Kelola Karyawan — avatar, name, status badge, role +
/// on-shift dot, start date, wage/hour.
class HrdEmployeeListCard extends StatelessWidget {
  final Employee employee;
  final bool onShift;
  final VoidCallback onTap;

  const HrdEmployeeListCard({super.key, required this.employee, required this.onShift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppItemThumbnail(name: employee.name, size: 46, radius: AppRadius.pill),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          employeeStatusBadge(employee.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(employee.role, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                          if (onShift) ...[
                            const Text(' · ', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                            const Icon(Icons.circle, size: 6, color: AppColors.success),
                            const SizedBox(width: 4),
                            const Text('Sedang Jaga', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ],
                        ],
                      ),
                      const Divider(height: AppSpacing.lg, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BEKERJA SEJAK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text(formatDateLong(employee.startDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('UPAH/JAM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                              const SizedBox(height: 2),
                              Text(formatRupiah(employee.wagePerHour), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
