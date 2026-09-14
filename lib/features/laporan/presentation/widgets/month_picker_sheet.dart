import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Month picker — the HTML mockup showed a static "Sep 2026" pill with
/// no picker behind it; since this is a real port (not a visual-only
/// shell), tapping it needs to actually change which month the report
/// covers. Kept intentionally simple (prev/next month arrows) rather
/// than a full calendar, since a report is always exactly one whole
/// month.
class MonthPickerSheet extends StatelessWidget {
  final DateTime current;
  final ValueChanged<DateTime> onSelect;

  const MonthPickerSheet({super.key, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Bulan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    onSelect(DateTime(current.year, current.month - 1, 1));
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(current),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                IconButton(
                  onPressed: current.year == now.year && current.month == now.month
                      ? null
                      : () {
                          onSelect(DateTime(current.year, current.month + 1, 1));
                          Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
