import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../application/hpp_opname_provider.dart';
import '../../domain/hpp_opname_models.dart';
import 'sliding_pill_tabs.dart';

/// HPP tab: search + 3-way category pill + ingredient list + inline
/// price editing. Ported 1:1 from the HTML mockup's HPP page.
class HppTabContent extends ConsumerWidget {
  const HppTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hppOpnameProvider);
    final controller = ref.read(hppOpnameProvider.notifier);
    final items = state.hppFilteredIngredients;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: SearchBarField(
            hintText: 'Cari bahan...',
            onChanged: controller.setHppSearchQuery,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SlidingPillTabs(
            labels: IngredientCategory.values.map((c) => c.label).toList(),
            selectedIndex: IngredientCategory.values.indexOf(state.hppCategory),
            onSelected: (i) => controller.setHppCategory(IngredientCategory.values[i]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('Bahan tidak ditemukan.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) => _IngredientRow(ingredient: items[index]),
                ),
        ),
      ],
    );
  }
}

/// Shared pill search field — same visual across the HPP tab and the
/// Stok Opname Input Baru sub-tab (both search the same ingredient
/// list), so this is public rather than duplicated per-file.
class SearchBarField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  const SearchBarField({super.key, this.hintText = 'Cari bahan...', required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends ConsumerWidget {
  final Ingredient ingredient;
  const _IngredientRow({required this.ingredient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showEditPriceSheet(context, ref, ingredient),
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppSpacing.sm)),
              child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ingredient.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('per ${ingredient.unit}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatRupiah(ingredient.lastPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text('/ ${ingredient.unit}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showEditPriceSheet(BuildContext context, WidgetRef ref, Ingredient ingredient) {
    final controller = TextEditingController(text: ingredient.lastPrice.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ingredient.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Harga ini kepakai ke semua Menu & Variant yang pakai bahan ini.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Harga / ${ingredient.unit}',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tileHpp,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final newPrice = int.tryParse(controller.text.replaceAll('.', '').replaceAll(',', ''));
                    if (newPrice != null) {
                      ref.read(hppOpnameProvider.notifier).updateIngredientPrice(ingredient.id, newPrice);
                    }
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Simpan Harga', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
