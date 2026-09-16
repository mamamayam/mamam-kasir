import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../dompet/application/dompet_provider.dart';
import '../../../dompet/domain/dompet_models.dart';
import '../../application/arus_kas_provider.dart';
import '../../domain/arus_kas_models.dart';

/// "Tambah Pemasukan/Pengeluaran" form, shown as a modal per the app's
/// stack-navigation convention (temporary action layered on the Arus
/// Kas screen). Fields, in order: Kategori (editable combobox) + Sumber
/// Dana side by side; Jumlah + Tanggal Transaksi side by side; Nama
/// Toko/Supplier (Pengeluaran only); Detail (optional); Simpan Data.
///
/// "Non-Tunai" lives inside the Sumber Dana dropdown alongside Dompet
/// Toko and each courier — there's deliberately no separate Jenis
/// Transaksi Tunai/Non-Tunai field, per [[mamam-kasir-flutter]] notes.
class AddArusKasModal extends ConsumerStatefulWidget {
  const AddArusKasModal({super.key});

  @override
  ConsumerState<AddArusKasModal> createState() => _AddArusKasModalState();
}

class _AddArusKasModalState extends ConsumerState<AddArusKasModal> {
  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _storeSupplierController = TextEditingController();
  final _detailController = TextEditingController();

  DateTime _transactionDate = DateTime.now();
  // null = "Non-Tunai"; otherwise a cash_location id ('loc-store' or a courier id).
  String? _selectedLocationId;

  bool _isSaving = false;
  String? _validationError;

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _storeSupplierController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _transactionDate = picked);
  }

  Future<void> _handleSave(ArusKasDirection direction) async {
    final category = _categoryController.text.trim();
    if (category.isEmpty) {
      setState(() => _validationError = 'Kategori wajib diisi.');
      return;
    }
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _validationError = 'Jumlah harus berupa angka lebih dari 0.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    final fundingSource = _selectedLocationId == null ? ArusKasFundingSource.nonCash : ArusKasFundingSource.cashLocation;

    final ok = await ref.read(arusKasProvider.notifier).addEntry(
          category: category,
          amount: amount,
          transactionDate: _transactionDate,
          fundingSource: fundingSource,
          sourceLocationId: _selectedLocationId,
          storeOrSupplierName: direction == ArusKasDirection.pengeluaran && _storeSupplierController.text.trim().isNotEmpty
              ? _storeSupplierController.text.trim()
              : null,
          detail: _detailController.text.trim().isEmpty ? null : _detailController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _validationError = 'Gagal menyimpan. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = ref.watch(arusKasProvider.select((s) => s.direction));
    final categories = ref.watch(arusKasProvider.select((s) => s.categories));
    final locationsAsync = ref.watch(cashLocationsProvider);
    final isPengeluaran = direction == ArusKasDirection.pengeluaran;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isPengeluaran ? 'Tambah Pengeluaran' : 'Tambah Pemasukan',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.textMuted), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CategoryField(controller: _categoryController, existingCategories: categories),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: locationsAsync.when(
                              data: (locations) => _SumberDanaField(
                                locations: locations,
                                selectedLocationId: _selectedLocationId,
                                onChanged: (id) => setState(() => _selectedLocationId = id),
                              ),
                              loading: () => const _FieldSkeleton(label: 'Sumber Dana'),
                              error: (_, __) => const _FieldSkeleton(label: 'Sumber Dana'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: 'Jumlah',
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(hint: 'Rp0'),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _LabeledField(
                              label: 'Tanggal Transaksi',
                              child: InkWell(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '${_transactionDate.day}/${_transactionDate.month}/${_transactionDate.year}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isPengeluaran) ...[
                        const SizedBox(height: AppSpacing.md),
                        _LabeledField(
                          label: 'Nama Toko/Supplier',
                          child: TextField(controller: _storeSupplierController, decoration: _fieldDecoration(hint: 'Opsional')),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _LabeledField(
                        label: 'Detail',
                        child: TextField(
                          controller: _detailController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: _fieldDecoration(hint: 'Opsional'),
                        ),
                      ),
                      if (_validationError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_validationError!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _handleSave(direction),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Simpan Data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration({required String hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.brand)),
  );
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  final String label;
  const _FieldSkeleton({required this.label});

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: label,
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
      ),
    );
  }
}

/// Editable combobox: type a new category, or tap the dropdown affordance
/// to pick from previously-used categories for the current direction.
class _CategoryField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> existingCategories;
  const _CategoryField({required this.controller, required this.existingCategories});

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: 'Kategori',
      child: Autocomplete<String>(
        optionsBuilder: (textEditingValue) {
          if (textEditingValue.text.isEmpty) return existingCategories;
          return existingCategories.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        onSelected: (selection) => controller.text = selection,
        fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
          // Route every keystroke straight into our own controller (the
          // one _handleSave reads from), instead of stacking a new
          // listener on Autocomplete's internal controller each rebuild.
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            onChanged: (value) => controller.text = value,
            decoration: _fieldDecoration(hint: 'Pilih atau ketik baru'),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: options
                      .map((o) => ListTile(dense: true, title: Text(o, style: const TextStyle(fontSize: 13)), onTap: () => onSelected(o)))
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sumber Dana dropdown: 'Non-Tunai' plus every active cash location
/// (Store Cash + couriers). Defaults to 'Non-Tunai' — the field mirrors
/// what the eventual real Sumber Dana dropdown does per the HTML
/// preview: no separate Tunai/Non-Tunai toggle, it's folded in here.
class _SumberDanaField extends StatefulWidget {
  final List<CashLocation> locations;
  final String? selectedLocationId;
  final ValueChanged<String?> onChanged;

  const _SumberDanaField({
    required this.locations,
    required this.selectedLocationId,
    required this.onChanged,
  });

  @override
  State<_SumberDanaField> createState() => _SumberDanaFieldState();
}

class _SumberDanaFieldState extends State<_SumberDanaField> {
  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: 'Sumber Dana',
      child: DropdownButtonFormField<String?>(
        value: widget.selectedLocationId,
        decoration: _fieldDecoration(hint: 'Non-Tunai'),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Non-Tunai')),
          ...widget.locations.map((loc) => DropdownMenuItem<String?>(value: loc.id, child: Text(loc.name))),
        ],
        onChanged: widget.onChanged,
      ),
    );
  }
}
