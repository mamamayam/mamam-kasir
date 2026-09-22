import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';

/// Owner Screen 7 — Riwayat Kehadiran. Shows either every employee's
/// current-month log ([employeeId] null) or one employee's, filterable by
/// log type, grouped by date (newest first).
class HrdOwnerAttendanceHistoryScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  const HrdOwnerAttendanceHistoryScreen({super.key, this.employeeId});

  @override
  ConsumerState<HrdOwnerAttendanceHistoryScreen> createState() => _HrdOwnerAttendanceHistoryScreenState();
}

class _HrdOwnerAttendanceHistoryScreenState extends ConsumerState<HrdOwnerAttendanceHistoryScreen> {
  AttendanceLogType? _typeFilter; // null = Semua

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);
    final employee = widget.employeeId != null ? state.employeeById(widget.employeeId!) : null;

    var rows = state.attendance.where((a) => a.date.startsWith(state.currentMonth) && (widget.employeeId == null || a.employeeId == widget.employeeId)).toList();
    if (_typeFilter != null) rows = rows.where((a) => a.type == _typeFilter).toList();
    rows.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return (b.time ?? '').compareTo(a.time ?? '');
    });

    final grouped = <String, List<AttendanceLog>>{};
    for (final r in rows) {
      grouped.putIfAbsent(r.date, () => []).add(r);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(title: Text(employee != null ? 'Riwayat ${employee.name}' : 'Riwayat Kehadiran')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _TypeChip(label: 'Semua', selected: _typeFilter == null, onTap: () => setState(() => _typeFilter = null)),
                      for (final t in const [AttendanceLogType.masuk, AttendanceLogType.bolong, AttendanceLogType.pulang, AttendanceLogType.libur])
                        _TypeChip(label: t.label, selected: _typeFilter == t, onTap: () => setState(() => _typeFilter = t)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (dates.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: AppEmptyState(icon: Icons.event_busy_rounded, title: 'Belum ada catatan')),
                  for (final date in dates) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                      child: Text(formatDateLong(date).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ),
                    for (final l in grouped[date]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCardShell(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(employee?.name ?? state.employeeById(l.employeeId)?.name ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                  Text(l.type.label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                ],
                              ),
                              Text(l.time ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
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

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
