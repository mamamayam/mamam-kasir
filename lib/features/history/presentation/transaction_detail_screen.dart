import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../../dompet/presentation/widgets/cash_location_picker.dart';
import '../../pos/application/cart_provider.dart';
import '../../pos/domain/order_models.dart';
import '../../pos/domain/transaction.dart';
import '../../pos/presentation/widgets/cart_drawer.dart';
import '../application/history_provider.dart';

/// Transaction detail screen. Reached via [AppNav.push] from
/// [HistoryScreen] — a "going deeper" destination per the app's
/// stack-navigation model, distinct from the checkout flow's
/// [ReceiptModal] (which is a temporary post-checkout confirmation, not
/// a browsable record).
class TransactionDetailScreen extends ConsumerWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Transaksi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaksi ${transaction.displayNumber} akan ditandai dibatalkan dan dikecualikan dari omzet. '
              'Tindakan ini tidak dapat dibatalkan kembali.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Alasan (opsional)', isDense: true, border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Batalkan', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(historyProvider.notifier).cancelTransaction(transaction.id, reason: reasonController.text.trim());

    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  /// "Selesaikan Pesanan" — for an `open` (Diproses) transaction that
  /// was never paid at checkout. Since no payment method was captured
  /// then, this dialog asks for one now (dropdown), with the same
  /// cash-location requirement as normal checkout when the order is
  /// Delivery + Tunai (reusing [CashLocationPicker] rather than
  /// re-deciding that rule here).
  Future<void> _confirmComplete(BuildContext context, WidgetRef ref) async {
    PaymentMethod? selectedMethod;
    String? selectedCashLocationId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final requiresCashLocation = transaction.orderType == OrderType.delivery && selectedMethod == PaymentMethod.tunai;
          final canConfirm = selectedMethod != null && (!requiresCashLocation || selectedCashLocationId != null);

          return AlertDialog(
            title: const Text('Selesaikan Pesanan?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transaksi ${transaction.displayNumber} akan ditandai Selesai dan masuk ke Dompet/Laporan.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<PaymentMethod>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Metode Pembayaran', isDense: true, border: OutlineInputBorder()),
                  items: const [PaymentMethod.tunai, PaymentMethod.qris, PaymentMethod.transfer]
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                      .toList(),
                  onChanged: (m) => setDialogState(() {
                    selectedMethod = m;
                    selectedCashLocationId = null;
                  }),
                ),
                if (requiresCashLocation) ...[
                  const SizedBox(height: AppSpacing.md),
                  CashLocationPicker(
                    selectedLocationId: selectedCashLocationId,
                    onChanged: (id) => setDialogState(() => selectedCashLocationId = id),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
              TextButton(
                onPressed: canConfirm ? () => Navigator.of(dialogContext).pop(true) : null,
                child: const Text('Selesaikan', style: TextStyle(color: AppColors.success)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(historyProvider.notifier).completeTransaction(
          transaction.id,
          paymentMethodLabel: selectedMethod!.label,
          amountPaid: transaction.total,
          cashLocationId: selectedCashLocationId,
        );

    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  /// "Edit Pesanan" — loads this transaction into the cart draft (see
  /// [CartController.loadFromTransaction]) and opens [CartDrawer] on
  /// top of it, same as the mockup's "detail screen first, then an
  /// explicit Edit action" flow (chosen specifically so the cart never
  /// ends up silently holding an in-progress edit if the app is closed
  /// while just browsing history).
  void _editOrder(BuildContext context, WidgetRef ref) {
    ref.read(cartProvider.notifier).loadFromTransaction(transaction);
    AppNav.showModal(context, builder: (_) => const CartDrawer());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCanceled = transaction.isCanceled;
    final isOpen = transaction.isOpen;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(title: Text(transaction.displayNumber)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (isCanceled) _CanceledBanner(reason: transaction.cancelReason, canceledAt: transaction.canceledAt),
                  if (isCanceled) const SizedBox(height: AppSpacing.lg),
                  if (isOpen) ...[
                    const Align(alignment: Alignment.centerLeft, child: AppStatusBadge('Diproses', AppColors.warning)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _DetailCard(transaction: transaction),
                ],
              ),
            ),
            if (isOpen)
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton.secondary(label: 'Edit Pesanan', onPressed: () => _editOrder(context, ref)),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.primary(label: 'Selesaikan Pesanan', onPressed: () => _confirmComplete(context, ref)),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton.danger(label: 'Batalkan Pesanan', onPressed: () => _confirmCancel(context, ref)),
                  ],
                ),
              )
            else if (!isCanceled)
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
                ),
                child: AppButton.danger(label: 'Batalkan Transaksi', onPressed: () => _confirmCancel(context, ref)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CanceledBanner extends StatelessWidget {
  final String? reason;
  final DateTime? canceledAt;
  const _CanceledBanner({required this.reason, required this.canceledAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.danger.withValues(alpha: 0.25))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_rounded, size: 18, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Transaksi Dibatalkan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.danger)),
                if (canceledAt != null)
                  Text(DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(canceledAt!), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.danger)),
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Alasan: $reason', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.danger)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Transaction transaction;
  const _DetailCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEEE, d MMMM yyyy · HH:mm', 'id_ID').format(transaction.createdAt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Tipe Pesanan', value: transaction.orderType.label),
          _InfoRow(label: 'Pelanggan', value: transaction.customerName ?? 'Pelanggan Umum'),
          if (transaction.ojolPlatform != null) _InfoRow(label: 'Platform', value: transaction.ojolPlatform!.label),
          if (transaction.ojolOrderNumber != null && transaction.ojolOrderNumber!.isNotEmpty) _InfoRow(label: 'No. Pesanan', value: transaction.ojolOrderNumber!),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          const Text('Item Pesanan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          ...transaction.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.qty}x ${item.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          if (item.variantName != null) Text(item.variantName!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                          if (item.note.isNotEmpty) Text('Catatan: ${item.note}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    Text(formatRupiah(item.lineTotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              )),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _AmountRow(label: 'Subtotal', value: transaction.subtotal),
          if (transaction.voucherDiscount > 0) _AmountRow(label: 'Diskon Voucher (${transaction.voucherCode})', value: -transaction.voucherDiscount),
          if (transaction.manualDiscountAmount > 0) _AmountRow(label: 'Diskon Manual', value: -transaction.manualDiscountAmount),
          if (transaction.taxAmount > 0) _AmountRow(label: 'Pajak', value: transaction.taxAmount),
          if (transaction.serviceAmount > 0) _AmountRow(label: 'Service', value: transaction.serviceAmount),
          if (transaction.deliveryFee > 0) _AmountRow(label: 'Ongkir', value: transaction.deliveryFee),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _AmountRow(label: 'TOTAL', value: transaction.total, isBold: true),
          const SizedBox(height: AppSpacing.md),
          if (transaction.paymentMethodLabel != null) _InfoRow(label: 'Metode Pembayaran', value: transaction.paymentMethodLabel!),
          if (transaction.splitPayments.isNotEmpty)
            ...transaction.splitPayments.map((p) => _InfoRow(label: '  • ${p.method.label}', value: formatRupiah(p.amount))),
          if (transaction.amountPaid != null) _AmountRow(label: 'Dibayar', value: transaction.amountPaid!),
          if (transaction.changeAmount != null && transaction.changeAmount! > 0) _AmountRow(label: 'Kembalian', value: transaction.changeAmount!),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 14 : 12.5, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: isBold ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(
            '${value < 0 ? '-' : ''}${formatRupiah(value.abs())}',
            style: TextStyle(fontSize: isBold ? 16 : 12.5, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: isBold ? AppColors.brand : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
