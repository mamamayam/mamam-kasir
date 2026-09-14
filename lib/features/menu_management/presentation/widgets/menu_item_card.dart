import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/menu_management_models.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final MenuViewMode viewMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MenuItemCard({super.key, required this.item, required this.viewMode, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (viewMode == MenuViewMode.list) {
      return _buildListLayout(context);
    }
    return _buildGridLayout(context);
  }

  Widget _buildListLayout(BuildContext context) {
    return Opacity(
      opacity: item.isActive ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _ItemThumbnail(size: 48, iconSize: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            item.isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                            size: 12,
                            color: item.isActive ? AppColors.success : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.isActive ? 'Aktif' : 'Nonaktif',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatRupiah(item.price),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    Text(
                      '/ ${item.unit}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    final isGrid3 = viewMode == MenuViewMode.grid3;

    return Opacity(
      opacity: item.isActive ? 1 : 0.55,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: _ItemThumbnail(size: double.infinity, iconSize: isGrid3 ? 22 : 28, rounded: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isGrid3 ? 10.5 : 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(item.price),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isGrid3 ? 10 : 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  '/ ${item.unit}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemThumbnail extends StatelessWidget {
  final double size;
  final double iconSize;
  final bool rounded;

  const _ItemThumbnail({required this.size, required this.iconSize, this.rounded = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: rounded ? null : size,
      height: rounded ? null : size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(rounded ? AppRadius.md : AppRadius.sm),
      ),
      child: Icon(Icons.inventory_2_rounded, size: iconSize, color: AppColors.textMuted),
    );
  }
}
