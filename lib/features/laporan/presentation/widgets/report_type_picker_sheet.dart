import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet_header.dart';
import '../../domain/laporan_models.dart';

/// "Pilih Jenis Laporan" picker: a bottom sheet with one row per
/// [ReportType], each with a circular icon and a checkmark on the
/// selected one.
///
/// Header uses [AppSheetHeader] per the component standards doc §11 —
/// the previous hand-rolled Row could collide title and close button.
/// The rows sit in a scrollable, shrink-wrapped [ListView] so the sheet
/// grows to its content but never overflows on a short screen (the old
/// fixed Column with `isScrollControlled: false` overflowed once the
/// list passed the 9/16-height cap).
class ReportTypePickerSheet extends StatelessWidget {
  final ReportType current;
  final ValueChanged<ReportType> onSelect;

  const ReportTypePickerSheet({super.key, required this.current, required this.onSelect});

  static const _icons = {
    ReportType.pendapatan: Icons.trending_up_rounded,
    ReportType.pengeluaran: Icons.trending_down_rounded,
    ReportType.labaRugi: Icons.account_balance_wallet_outlined,
    ReportType.produk: Icons.inventory_2_outlined,
    ReportType.customer: Icons.people_alt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: AppSheetHeader(title: 'Pilih Jenis Laporan'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: ReportType.values.map((type) {
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
                            child: Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          if (!type.isImplemented)
                            const Padding(
                              padding: EdgeInsets.only(right: AppSpacing.sm),
                              child: Text(
                                'SEGERA',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.25, color: AppColors.textMuted),
                              ),
                            ),
                          if (isSelected) const Icon(Icons.check_rounded, size: 18, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
