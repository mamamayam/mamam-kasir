import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';

/// Owner Screen 10 — Rekap Kinerja: per-employee hari hadir / hari full
/// time / blok lembur for the current month, sorted by most days present.
class HrdOwnerPerformanceRecapScreen extends ConsumerWidget {
  const HrdOwnerPerformanceRecapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final period = state.currentMonthPeriod;

    final rows = state.employees.where((e) => e.status != EmployeeStatus.resign).map((e) => (employee: e, att: state.attendanceFor(e, period))).toList()
      ..sort((a, b) => b.att.hadirDays.compareTo(a.att.hadirDays));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Rekap Kinerja')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text(monthLabel(state.currentMonth), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  for (final row in rows) ...[
                    AppCardShell(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppItemThumbnail(name: row.employee.name, size: 40, radius: AppRadius.pill),
                              const SizedBox(width: AppSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.employee.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  Text(row.employee.role, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: _Stat(value: '${row.att.hadirDays}', label: 'Hari Hadir')),
                              Expanded(child: _Stat(value: '${row.att.fullTimeDays}', label: 'Full Time')),
                              Expanded(
                                child: _Stat(
                                  value: '${row.att.overtimeBlocks30Min}',
                                  label: 'Blok Lembur',
                                  color: row.att.overtimeBlocks30Min > 0 ? AppColors.warning : AppColors.brand,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _Stat({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
