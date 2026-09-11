import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/order_models.dart';
import '../../domain/transaction.dart';

/// Digital receipt, shown after a successful checkout. Physical
/// (Bluetooth ESC/POS) printing is a separate, later feature — this is
/// the on-screen struk only.
class ReceiptModal extends StatelessWidget {
  final Transaction transaction;
  final int changeAmount;

  const ReceiptModal({super.key, required this.transaction, required this.changeAmount});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Center(
                  child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill))),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
                  children: [
                    _SuccessHeader(transaction: transaction),
                    const SizedBox(height: AppSpacing.xl),
                    _ReceiptCard(transaction: transaction, changeAmount: changeAmount),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      elevation: 0,
                    ),
                    child: const Text('Selesai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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

class _SuccessHeader extends StatelessWidget {
  final Transaction transaction;
  const _SuccessHeader({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 32, color: AppColors.success),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Pembayaran Berhasil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(transaction.displayNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Transaction transaction;
  final int changeAmount;
  const _ReceiptCard({required this.transaction, required this.changeAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text('Mamam Kasir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(transaction.createdAt),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DashedDivider(),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Tipe Pesanan', value: transaction.orderType.label),
          if (transaction.customerName != null) _InfoRow(label: 'Pelanggan', value: transaction.customerName!),
          if (transaction.ojolPlatform != null) _InfoRow(label: 'Platform', value: transaction.ojolPlatform!.label),
          if (transaction.ojolOrderNumber != null && transaction.ojolOrderNumber!.isNotEmpty)
            _InfoRow(label: 'No. Pesanan', value: transaction.ojolOrderNumber!),
          const SizedBox(height: AppSpacing.md),
          _DashedDivider(),
          const SizedBox(height: AppSpacing.md),
          ...transaction.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.qty}x ${item.name}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          if (item.variantName != null)
                            Text(item.variantName!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Text(formatRupiah(item.lineTotal), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.sm),
          _DashedDivider(),
          const SizedBox(height: AppSpacing.sm),
          _AmountRow(label: 'Subtotal', value: transaction.subtotal),
          if (transaction.voucherDiscount > 0) _AmountRow(label: 'Diskon Voucher (${transaction.voucherCode})', value: -transaction.voucherDiscount),
          if (transaction.manualDiscountAmount > 0) _AmountRow(label: 'Diskon Manual', value: -transaction.manualDiscountAmount),
          if (transaction.taxAmount > 0) _AmountRow(label: 'Pajak', value: transaction.taxAmount),
          if (transaction.serviceAmount > 0) _AmountRow(label: 'Service', value: transaction.serviceAmount),
          if (transaction.deliveryFee > 0) _AmountRow(label: 'Ongkir', value: transaction.deliveryFee),
          const SizedBox(height: AppSpacing.sm),
          _DashedDivider(),
          const SizedBox(height: AppSpacing.sm),
          _AmountRow(label: 'TOTAL', value: transaction.total, isBold: true),
          if (transaction.paymentMethodLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Metode', value: transaction.paymentMethodLabel!),
          ],
          if (transaction.amountPaid != null && transaction.paymentMethodLabel != 'Ojol')
            _AmountRow(label: 'Dibayar', value: transaction.amountPaid!),
          if (changeAmount > 0) _AmountRow(label: 'Kembalian', value: changeAmount),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashCount = (constraints.maxWidth / 8).floor();
          return Row(
            children: List.generate(
              dashCount,
              (index) => Expanded(child: Container(height: 1, color: index.isEven ? AppColors.border : Colors.transparent)),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final int value;
  final bool isBold;
  const _AmountRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 13.5 : 12, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: isBold ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(
            '${value < 0 ? '-' : ''}${formatRupiah(value.abs())}',
            style: TextStyle(fontSize: isBold ? 15 : 12, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: isBold ? AppColors.brand : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
