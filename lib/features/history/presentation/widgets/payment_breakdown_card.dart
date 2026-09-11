import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/history_models.dart';

class PaymentBreakdownCard extends StatelessWidget {
  final List<PaymentMethodBreakdown> breakdown;
  final String? selectedMethod;
  final ValueChanged<String?> onSelect;

  const PaymentBreakdownCard({super.key, required this.breakdown, required this.selectedMethod, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final grandTotal = breakdown.fold<int>(0, (sum, b) => sum + b.total);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('Omset per Metode Pembayaran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _BreakdownChip(
                label: 'Semua',
                total: grandTotal,
                count: null,
                isSelected: selectedMethod == null,
                onTap: () => onSelect(null),
              ),
              ...breakdown.map((b) => _BreakdownChip(
                    label: b.method,
                    total: b.total,
                    count: b.count,
                    isSelected: selectedMethod == b.method,
                    onTap: () => onSelect(selectedMethod == b.method ? null : b.method),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  final String label;
  final int total;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _BreakdownChip({required this.label, required this.total, required this.count, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? AppColors.textPrimary : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count != null ? '$label · ${count}x' : label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted),
            ),
            Text(
              formatRupiah(total),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
