import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/menu_management_models.dart';

class VariantGroupCard extends StatelessWidget {
  final VariantGroup group;
  final MenuViewMode viewMode;
  final VoidCallback? onTap;

  const VariantGroupCard({super.key, required this.group, required this.viewMode, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isList = viewMode == MenuViewMode.list;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(isList ? AppRadius.xl : AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isList ? AppRadius.xl : AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isList ? AppRadius.xl : AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: isList ? _buildListContent() : _buildGridContent(),
        ),
      ),
    );
  }

  Widget _buildListContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                group.name,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${group.options.length} Pilihan',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.brand),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: group.options
              .map((opt) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      opt,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildGridContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          group.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '${group.options.length} Pilihan',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.brand),
          ),
        ),
      ],
    );
  }
}
