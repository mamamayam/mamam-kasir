import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';

/// Staff Screen 7 — Tambah Pemasukan. MUST wait for approval — the
/// request only enters payroll once decided in [HrdOwnerApprovalScreen].
class HrdStaffAddIncomeScreen extends ConsumerStatefulWidget {
  final String employeeId;
  const HrdStaffAddIncomeScreen({super.key, required this.employeeId});

  @override
  ConsumerState<HrdStaffAddIncomeScreen> createState() => _HrdStaffAddIncomeScreenState();
}

class _HrdStaffAddIncomeScreenState extends ConsumerState<HrdStaffAddIncomeScreen> {
  static const _categories = ['Bonus', 'THR', 'Ongkir', 'Tambahan Lainnya'];
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = _categories.first;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final state = ref.read(hrdControllerProvider);
    final result = ref.read(hrdControllerProvider.notifier).submitStaffIncome(
          employeeId: widget.employeeId,
          category: _category,
          amountText: _amountController.text,
          date: state.today,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Tambah Pemasukan')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
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
                  AppTextField.form(label: 'Keterangan (opsional)', controller: _noteController, hintText: 'Catatan tambahan', minLines: 2, maxLines: 4),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Pengajuan akan menunggu persetujuan Owner sebelum masuk ke gaji.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(label: 'Kirim Pengajuan', fullWidth: true, onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
