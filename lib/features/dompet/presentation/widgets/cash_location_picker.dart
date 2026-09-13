import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/dompet_provider.dart';
import '../../domain/dompet_models.dart';

/// Checkout-side entry point into the Dompet ledger (see
/// [[dompet-prd]]): when an order is Delivery/Ojol and paid in cash,
/// the cashier must say where that cash physically is — handed
/// straight to the store, or held by a specific courier. This is what
/// [PosRepository.saveTransaction] uses as `cashLocationId` to record
/// the resulting cash movement.
///
/// Courier options are read from [CashLocationType.courier] cash
/// locations, which are manual/dummy entries for now — see
/// [[dompet-prd]] on why (no Staff module yet to source a real list).
class CashLocationPicker extends ConsumerWidget {
  final String? selectedLocationId;
  final ValueChanged<String> onChanged;

  const CashLocationPicker({super.key, required this.selectedLocationId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(cashLocationsProvider);

    return locationsAsync.when(
      loading: () => const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
      data: (locations) {
        if (locations.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Uang Diterima Oleh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Text(
              'Untuk pengiriman cash, catat siapa yang memegang uang ini.',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: locations.map((loc) {
                final isSelected = selectedLocationId == loc.id;
                final isStore = loc.type == CashLocationType.store;
                return InkWell(
                  onTap: () => onChanged(loc.id),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brand.withValues(alpha: 0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: isSelected ? AppColors.brand : AppColors.border, width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isStore ? Icons.storefront_rounded : Icons.moped_rounded,
                          size: 16,
                          color: isSelected ? AppColors.brand : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          loc.name,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isSelected ? AppColors.brand : AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
