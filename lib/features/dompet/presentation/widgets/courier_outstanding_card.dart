import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/dompet_models.dart';

/// One courier's outstanding cash, with the two PRD-mandated resolution
/// actions — "Sudah Disetor" and "Jadikan Kasbon". No "will deposit
/// later" option exists here, per PRD §17.
class CourierOutstandingCard extends StatelessWidget {
  final CashLocationBalance balance;
  final ValueChanged<int> onDeposit; // amount actually handed over (supports partial, PRD §10)
  final VoidCallback onConvertToKasbon;

  const CourierOutstandingCard({
    super.key,
    required this.balance,
    required this.onDeposit,
    required this.onConvertToKasbon,
  });

  Future<void> _showDepositDialog(BuildContext context) async {
    final controller = TextEditingController(text: balance.balance.toString());

    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Setoran ${balance.location.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding saat ini: ${formatRupiah(balance.balance)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(prefixText: 'Rp ', labelText: 'Jumlah disetor', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim()) ?? 0;
              if (value > 0 && value <= balance.balance) {
                Navigator.of(context).pop(value);
              }
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (amount != null) onDeposit(amount);
  }

  Future<void> _showKasbonConfirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jadikan Kasbon?'),
        content: Text(
          '${formatRupiah(balance.balance)} milik ${balance.location.name} akan dikonversi menjadi kasbon/hutang staff. '
          'Tidak mengubah transaksi penjualan yang sudah ada.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Ya, Jadikan Kasbon')),
        ],
      ),
    );

    if (confirmed == true) onConvertToKasbon();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.moped_rounded, size: 18, color: AppColors.warning),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(balance.location.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const Text('Belum disetor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Text(formatRupiah(balance.balance), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showDepositDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Sudah Disetor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showKasbonConfirm(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Jadikan Kasbon', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
