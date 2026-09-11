import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Bottom sheet listing all categories (plus "Semua") as a checklist.
/// Returns the selected category name via [Navigator.pop], or `null`
/// for "Semua". Presented from the Kasir toolbar's filter icon.
class CategoryFilterSheet extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;

  const CategoryFilterSheet({
    super.key,
    required this.categories,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text(
              'Filter Kategori',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CategoryRow(
              label: 'Semua',
              selected: selectedCategory == null,
              onTap: () => Navigator.of(context).pop(),
            ),
            ...categories.map(
              (cat) => _CategoryRow(
                label: cat,
                selected: selectedCategory == cat,
                onTap: () => Navigator.of(context).pop(cat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.brand : AppColors.textPrimary,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.brand : Colors.transparent,
                border: Border.all(color: selected ? AppColors.brand : AppColors.border, width: 1.5),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
