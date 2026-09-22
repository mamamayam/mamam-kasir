import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';
import '../../domain/payroll_engine.dart';
import '../widgets/hrd_shared_widgets.dart';
import 'hrd_owner_attendance_history_screen.dart';
import 'hrd_owner_correct_attendance_screen.dart';

/// Owner Screen 5 — Kehadiran Hari Ini: live status for every
/// aktif/freelance employee. Tap a row to open Koreksi Absen.
class HrdOwnerAttendanceTodayScreen extends ConsumerWidget {
  const HrdOwnerAttendanceTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final rows = state.workingEmployees;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Kehadiran Hari Ini')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text(formatDateLong(state.today), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  for (final e in rows) ...[
                    _AttendanceRow(
                      name: e.name,
                      role: e.role,
                      status: todayStatus(state.todayLogsFor(e.id), e, state.today),
                      onShift: isOnShiftNow(state.todayLogsFor(e.id)),
                      onTap: () => AppNav.push(context, (_) => HrdOwnerCorrectAttendanceScreen(employeeId: e.id)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppButton.secondary(
                    label: 'Riwayat Kehadiran Semua Karyawan',
                    icon: Icons.history_rounded,
                    fullWidth: true,
                    onPressed: () => AppNav.push(context, (_) => const HrdOwnerAttendanceHistoryScreen()),
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

class _AttendanceRow extends StatelessWidget {
  final String name;
  final String role;
  final DayStatus status;
  final bool onShift;
  final VoidCallback onTap;

  const _AttendanceRow({required this.name, required this.role, required this.status, required this.onShift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              AppItemThumbnail(name: name, size: 44, radius: AppRadius.pill),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                        dayStatusBadge(status, onShift: onShift),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
