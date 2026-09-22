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

enum _HistoryFilter { semua, masuk, keluar }

/// Staff Screen 5 — Riwayat: this employee's own attendance log, filtered
/// Masuk/Pulang vs everything else, grouped by date (newest first).
class HrdStaffHistoryScreen extends ConsumerStatefulWidget {
  final String employeeId;
  const HrdStaffHistoryScreen({super.key, required this.employeeId});

  @override
  ConsumerState<HrdStaffHistoryScreen> createState() => _HrdStaffHistoryScreenState();
}

class _HrdStaffHistoryScreenState extends ConsumerState<HrdStaffHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.semua;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);

    var rows = state.attendance.where((a) => a.employeeId == widget.employeeId && a.date.startsWith(state.currentMonth)).toList();
    if (_filter == _HistoryFilter.masuk) {
      rows = rows.where((a) => a.type == AttendanceLogType.masuk || a.type == AttendanceLogType.masukLagi).toList();
    } else if (_filter == _HistoryFilter.keluar) {
      rows = rows.where((a) => a.type == AttendanceLogType.pulang || a.type == AttendanceLogType.bolong).toList();
    }
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
            const IosPageHeader(title: Text('Riwayat')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      _Chip(label: 'Semua', selected: _filter == _HistoryFilter.semua, onTap: () => setState(() => _filter = _HistoryFilter.semua)),
                      _Chip(label: 'Masuk', selected: _filter == _HistoryFilter.masuk, onTap: () => setState(() => _filter = _HistoryFilter.masuk)),
                      _Chip(label: 'Keluar', selected: _filter == _HistoryFilter.keluar, onTap: () => setState(() => _filter = _HistoryFilter.keluar)),
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
                              Text(l.type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

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
