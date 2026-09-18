import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card_shell.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/dompet_provider.dart';
import '../domain/dompet_models.dart';

/// "Tutup Dompet" — closes Store Cash for the period since the previous
/// closing. Per PRD: blocked while any courier still holds outstanding
/// cash, computes Expected Cash from the ledger, and asks the kasir to
/// enter the physically counted amount; any difference is recorded as
/// its own adjustment movement rather than editing the ledger.
///
/// No Shift module exists yet — see [[dompet-prd]] / DompetClosing's
/// doc comment for how this reconciles once Shift lands.
class DompetClosingScreen extends ConsumerStatefulWidget {
  const DompetClosingScreen({super.key});

  @override
  ConsumerState<DompetClosingScreen> createState() => _DompetClosingScreenState();
}

class _DompetClosingScreenState extends ConsumerState<DompetClosingScreen> {
  final _countedController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _countedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(closingProvider);
    final controller = ref.read(closingProvider.notifier);

    ref.listen(closingProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.danger));
      }
      if (next.committed != null && previous?.committed == null) {
        _showResultSheet(context, next.committed!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Tutup Dompet')),
            Expanded(
              child: state.isLoading || state.preview == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : _Body(
                      preview: state.preview!,
                      countedController: _countedController,
                      noteController: _noteController,
                      isSubmitting: state.isSubmitting,
                      onSubmit: () async {
                        final counted = int.tryParse(_countedController.text.trim());
                        if (counted == null || counted < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Masukkan jumlah uang fisik yang valid.'), backgroundColor: AppColors.danger),
                          );
                          return;
                        }
                        await controller.submit(
                          countedCash: counted,
                          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultSheet(BuildContext context, DompetClosing closing) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ClosingResultSheet(
        closing: closing,
        onDone: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DompetClosingPreview preview;
  final TextEditingController countedController;
  final TextEditingController noteController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _Body({
    required this.preview,
    required this.countedController,
    required this.noteController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
            children: [
              if (!preview.canClose) _BlockedCard(preview: preview),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel(text: 'RINGKASAN KAS'),
              const SizedBox(height: AppSpacing.sm),
              AppCardShell(
                child: Column(
                  children: [
                    _SummaryRow(label: 'Saldo Awal', value: preview.openingBalance),
                    _SummaryRow(label: 'Penjualan Cash', value: preview.cashSalesTotal, positive: true),
                    _SummaryRow(label: 'Setoran Kurir', value: preview.courierDepositsTotal, positive: true),
                    _SummaryRow(label: 'Pengeluaran Cash', value: preview.cashExpensesTotal, positive: false),
                    const Divider(height: AppSpacing.lg),
                    _SummaryRow(label: 'Kas Diharapkan (Expected Cash)', value: preview.expectedCash, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionLabel(text: 'HITUNG FISIK'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField.form(
                controller: countedController,
                enabled: preview.canClose && !isSubmitting,
                keyboardType: TextInputType.number,
                hintText: 'Jumlah uang fisik dihitung',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField.form(
                controller: noteController,
                enabled: preview.canClose && !isSubmitting,
                minLines: 2,
                maxLines: 4,
                hintText: 'Catatan (opsional)',
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
          child: AppButton.primary(
            label: 'Tutup Dompet',
            onPressed: preview.canClose && !isSubmitting ? onSubmit : null,
            isLoading: isSubmitting,
          ),
        ),
      ],
    );
  }
}

class _BlockedCard extends StatelessWidget {
  final DompetClosingPreview preview;
  const _BlockedCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      backgroundColor: AppColors.danger.withValues(alpha: 0.08),
      borderColor: AppColors.danger.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_rounded, size: 18, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Belum bisa tutup dompet',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Selesaikan dulu uang kurir berikut (setor atau jadikan kasbon) sebelum menutup dompet.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...preview.outstandingCouriers.map(
            (b) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(b.location.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(formatRupiah(b.balance), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.danger)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final bool? positive;
  final bool bold;
  const _SummaryRow({required this.label, required this.value, this.positive, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final color = bold
        ? AppColors.textPrimary
        : positive == null
            ? AppColors.textPrimary
            : (positive! ? AppColors.success : AppColors.danger);
    final sign = positive == null ? '' : (positive! ? '+' : '-');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 13 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: AppColors.textSecondary)),
          Text(
            '$sign${formatRupiah(value)}',
            style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5));
  }
}

class _ClosingResultSheet extends StatelessWidget {
  final DompetClosing closing;
  final VoidCallback onDone;
  const _ClosingResultSheet({required this.closing, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final hasDiscrepancy = closing.discrepancy != 0;
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 30),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Dompet Ditutup', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Kas Diharapkan: ${formatRupiah(closing.expectedCash)}\nKas Dihitung: ${formatRupiah(closing.countedCash)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          if (hasDiscrepancy) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              closing.discrepancy > 0 ? 'Selisih lebih ${formatRupiah(closing.discrepancy)}' : 'Selisih kurang ${formatRupiah(closing.discrepancy.abs())}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: closing.discrepancy > 0 ? AppColors.success : AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(label: 'Selesai', onPressed: onDone),
        ],
      ),
    );
  }
}
