import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/laporan_models.dart';

/// "Pilih Jenis Laporan" picker, ported 1:1 from the HTML mockup: a
/// bottom sheet with a close button and one row per [ReportType], each
/// with a circular icon and a checkmark on the selected one.
class ReportTypePickerSheet extends StatelessWidget {
  final ReportType current;
  final ValueChanged<ReportType> onSelect;

  const ReportTypePickerSheet({super.key, required this.current, required this.onSelect});

  static const _icons = {
    ReportType.pendapatan: Icons.trending_up_rounded,
    ReportType.pengeluaran: Icons.trending_down_rounded,
    ReportType.laba: Icons.account_balance_wallet_outlined,
    ReportType.produk: Icons.inventory_2_outlined,
    ReportType.customer: Icons.people_alt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pilih Jenis Laporan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Material(
                    color: AppColors.background,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...ReportType.values.map((type) {
              final isSelected = type == current;
              return InkWell(
                onTap: () {
                  onSelect(type);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.info.withValues(alpha: 0.12) : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icons[type], size: 19, color: isSelected ? AppColors.info : AppColors.textSecondary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(type.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                      if (isSelected) const Icon(Icons.check_rounded, size: 18, color: AppColors.textPrimary),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
