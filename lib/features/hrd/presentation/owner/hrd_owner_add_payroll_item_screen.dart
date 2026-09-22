import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';

/// Owner Screen 8 — Tambah Penghasilan/Potongan. Generic form for
/// Bonus/THR/Ongkir/Tambahan Lainnya (income) or Kasbon/Potongan Lainnya
/// (deduction) — Owner-entered, always effective immediately, unlike
/// staff income submissions which need approval.
class HrdOwnerAddPayrollItemScreen extends ConsumerStatefulWidget {
  final String employeeId;
  final bool isAddition;
  const HrdOwnerAddPayrollItemScreen({super.key, required this.employeeId, required this.isAddition});

  @override
  ConsumerState<HrdOwnerAddPayrollItemScreen> createState() => _HrdOwnerAddPayrollItemScreenState();
}

class _HrdOwnerAddPayrollItemScreenState extends ConsumerState<HrdOwnerAddPayrollItemScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late List<String> _categories;
  late String _category;
  late String _date;

  @override
  void initState() {
    super.initState();
    _categories = widget.isAddition ? const ['Bonus', 'THR', 'Ongkir', 'Tambahan Lainnya'] : const ['Kasbon', 'Potongan Lainnya'];
    _category = _categories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(String today) async {
    final initial = DateTime.tryParse(_date) ?? parseIsoDate(today);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) setState(() => _date = formatIsoDate(picked));
  }

  void _submit() {
    final result = ref.read(hrdControllerProvider.notifier).addPayrollItem(
          employeeId: widget.employeeId,
          isAddition: widget.isAddition,
          category: _category,
          amountText: _amountController.text,
          date: _date,
          note: _noteController.text,
        );
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);
    final e = state.employeeById(widget.employeeId);
    if (_date.isEmpty) _date = state.today;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(title: Text(widget.isAddition ? 'Tambah Penghasilan' : 'Tambah Potongan')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      children: [
                        const TextSpan(text: 'Untuk '),
                        TextSpan(text: e?.name ?? '-', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700)),
                        TextSpan(text: ' · ${monthLabel(state.currentMonth)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Jenis', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), color: AppColors.surface),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.form(label: 'Nominal', controller: _amountController, hintText: '0', keyboardType: TextInputType.number, prefixText: 'Rp '),
                  const SizedBox(height: AppSpacing.md),
                  _DatePickerField(label: 'Tanggal', value: _date, onTap: () => _pickDate(state.today)),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.form(label: 'Keterangan (opsional)', controller: _noteController, hintText: 'Catatan tambahan', minLines: 2, maxLines: 4),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.isAddition ? 'Langsung ditambahkan ke penghasilan bulan ini.' : 'Langsung mengurangi gaji bersih bulan ini.',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(label: 'Simpan', fullWidth: true, onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), color: AppColors.surface),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDateLong(value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
