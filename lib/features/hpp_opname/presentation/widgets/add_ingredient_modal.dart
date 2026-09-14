import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/hpp_opname_provider.dart';
import '../../domain/hpp_opname_models.dart';

/// "Tambah Bahan" form, reached via the header's "+" button on the HPP
/// page. Not present as a built screen in the HTML mockup (it only
/// showed the button) — this is a straightforward add-form consistent
/// with [AddMenuItemModal]'s shape, not a new design decision.
class AddIngredientModal extends ConsumerStatefulWidget {
  final IngredientCategory initialCategory;
  const AddIngredientModal({super.key, required this.initialCategory});

  @override
  ConsumerState<AddIngredientModal> createState() => _AddIngredientModalState();
}

class _AddIngredientModalState extends ConsumerState<AddIngredientModal> {
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  late IngredientCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty && _unitController.text.trim().isNotEmpty;

  void _save() {
    final price = int.tryParse(_priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    ref.read(hppOpnameProvider.notifier).addIngredient(
          category: _category,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          lastPrice: price,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tambah Bahan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              children: IngredientCategory.values.map((c) {
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.tileHpp,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: selected ? AppColors.tileHpp : AppColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Nama Bahan',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Satuan (kg, liter, pcs)',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Harga',
                      prefixText: 'Rp ',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tileHpp,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  elevation: 0,
                ),
                child: const Text('Simpan Bahan', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
