import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/menu_management_provider.dart';
import '../../domain/menu_management_models.dart';

/// "Tambah Menu" / "Edit Menu" form, shown as a modal (slide up from
/// bottom) per the stack-navigation convention: this is a temporary
/// action layered on the Menu Management screen, not a new destination.
///
/// Pass [editingItem] to open in edit mode (fields pre-filled, submit
/// updates instead of creates). Leaving it null opens in add mode.
class AddMenuItemModal extends ConsumerStatefulWidget {
  final MenuItem? editingItem;

  const AddMenuItemModal({super.key, this.editingItem});

  @override
  ConsumerState<AddMenuItemModal> createState() => _AddMenuItemModalState();
}

class _AddMenuItemModalState extends ConsumerState<AddMenuItemModal> {
  static const _categories = ['Makanan Utama', 'Minuman', 'Saus & Bumbu', 'Snack'];
  static const _units = ['porsi', 'pcs', 'gelas', 'pack'];

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _hppController;

  late String _selectedCategory;
  late String _selectedUnit;
  final Set<String> _selectedVariantIds = {};

  bool _isSaving = false;
  String? _validationError;

  bool get _isEditMode => widget.editingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editingItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(text: item != null ? item.price.toString() : '');
    _hppController = TextEditingController(text: item?.hpp != null ? item!.hpp.toString() : '');

    _selectedCategory = item != null && _categories.contains(item.categoryName) ? item.categoryName : _categories.first;
    _selectedUnit = item != null && _units.contains(item.unit) ? item.unit : _units.first;

    if (item != null) {
      _selectedVariantIds.addAll(item.variantGroupIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _hppController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();

    if (name.isEmpty) {
      setState(() => _validationError = 'Nama menu wajib diisi.');
      return;
    }
    final price = int.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() => _validationError = 'Harga jual harus berupa angka lebih dari 0.');
      return;
    }
    final hppText = _hppController.text.trim();
    final hpp = hppText.isEmpty ? null : int.tryParse(hppText);
    if (hppText.isNotEmpty && hpp == null) {
      setState(() => _validationError = 'HPP harus berupa angka.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    final controller = ref.read(menuManagementProvider.notifier);

    if (_isEditMode) {
      await controller.updateMenuItem(widget.editingItem!.copyWith(
        categoryName: _selectedCategory,
        name: name,
        price: price,
        hpp: hpp,
        unit: _selectedUnit,
        variantGroupIds: _selectedVariantIds.toList(),
      ));
    } else {
      await controller.createMenuItem(
        categoryName: _selectedCategory,
        name: name,
        price: price,
        hpp: hpp,
        unit: _selectedUnit,
        variantGroupIds: _selectedVariantIds.toList(),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final variantGroups = ref.watch(menuManagementProvider).variantGroups;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        ),
                        Text(
                          _isEditMode ? 'Edit Menu' : 'Tambah Menu',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 110),
                      children: [
                        if (_validationError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _validationError!,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _FieldLabel('NAMA MENU'),
                        _TextField(controller: _nameController, hint: 'Contoh: Ayam Bakar Spesial'),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('KATEGORI'),
                                  _Dropdown(
                                    value: _selectedCategory,
                                    options: _categories,
                                    onChanged: (v) => setState(() => _selectedCategory = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('SATUAN'),
                                  _Dropdown(
                                    value: _selectedUnit,
                                    options: _units,
                                    onChanged: (v) => setState(() => _selectedUnit = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('HARGA JUAL'),
                                  _TextField(controller: _priceController, hint: '0', prefix: 'Rp', isNumeric: true),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('HPP (MODAL)'),
                                  _TextField(controller: _hppController, hint: '0', prefix: 'Rp', isNumeric: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _FieldLabel('KONEKSI VARIAN', trailing: false),
                            const Text('Pilih (Opsional)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...variantGroups.map((vg) => _VariantCheckboxTile(
                              group: vg,
                              selected: _selectedVariantIds.contains(vg.id),
                              onChanged: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedVariantIds.add(vg.id);
                                  } else {
                                    _selectedVariantIds.remove(vg.id);
                                  }
                                });
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
              // Sticky "Simpan Data" footer, pinned regardless of the
              // sheet's internal scroll position.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(top: BorderSide(color: AppColors.border)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('Simpan Data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool trailing;
  const _FieldLabel(this.text, {this.trailing = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: trailing ? 6 : 0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool isNumeric;

  const _TextField({required this.controller, required this.hint, this.prefix, this.isNumeric = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          prefixText: prefix != null ? '$prefix ' : null,
          prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _Dropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _VariantCheckboxTile extends StatelessWidget {
  final VariantGroup group;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _VariantCheckboxTile({required this.group, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: selected ? AppColors.brand.withValues(alpha: 0.4) : AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Checkbox(
                    value: selected,
                    onChanged: (v) => onChanged(v ?? false),
                    activeColor: AppColors.brand,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        group.options.map((o) => o.name).join(', '),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
