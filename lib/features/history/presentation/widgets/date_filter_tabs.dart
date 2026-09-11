import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/history_models.dart';

class DateFilterTabs extends StatelessWidget {
  final HistoryDateFilter selected;
  final ValueChanged<HistoryDateFilter> onChanged;

  const DateFilterTabs({super.key, required this.selected, required this.onChanged});

  static const _tabs = [
    HistoryDateFilter.hariIni,
    HistoryDateFilter.kemarin,
    HistoryDateFilter.bulanIni,
    HistoryDateFilter.semua,
    HistoryDateFilter.custom,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: _tabs.map((tab) {
          final isSelected = selected == tab;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => onChanged(tab),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.textPrimary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: isSelected ? AppColors.textPrimary : AppColors.border),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
