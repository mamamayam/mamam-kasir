import 'package:flutter/material.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/history_models.dart';

Future<void> showSortSheet(BuildContext context, {required HistorySortKey current, required ValueChanged<HistorySortKey> onSelect}) {
  return AppNav.showModal(
    context,
    isScrollControlled: false,
    builder: (context) => SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill))),
            const SizedBox(height: AppSpacing.lg),
            ...HistorySortKey.values.map((key) {
              final selected = key == current;
              return ListTile(
                title: Text(key.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.brand : AppColors.textPrimary)),
                trailing: selected ? const Icon(Icons.check_rounded, color: AppColors.brand) : null,
                onTap: () {
                  onSelect(key);
                  Navigator.of(context).pop();
                },
              );
            }),
          ],
        ),
      ),
    ),
  );
}
