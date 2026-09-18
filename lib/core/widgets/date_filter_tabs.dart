import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Individual-chip date/option filter row per the component standards
/// doc §12 — for 4+ options that may need to scroll horizontally.
/// Separate pill-shaped chips, height 36, [AppRadius.pill], filled
/// [AppColors.textPrimary] when active.
///
/// Originally built for Riwayat Transaksi's date filter row — now the
/// shared widget for any 4+ option horizontal filter app-wide (e.g.
/// Arus Kas's Hari Ini/Kemarin/Bulan Ini/Bulan Kemarin/Pilih Tanggal).
/// For 2–3 options that must fit side by side full-width, use
/// [SlidingPillTabs] instead — don't invent a third tab pattern.
class DateFilterTabs<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  const DateFilterTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: options.map((option) {
          final isSelected = option == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => onSelected(option),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.textPrimary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: isSelected ? AppColors.textPrimary : AppColors.border),
                ),
                child: Text(
                  labelBuilder(option),
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
