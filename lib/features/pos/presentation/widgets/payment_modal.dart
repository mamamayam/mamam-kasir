import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../application/cart_provider.dart';
import '../../application/payment_modal_provider.dart';
import '../../domain/cart_state.dart';
import '../../domain/checkout_calculator.dart';
import '../../domain/order_models.dart';
import '../../domain/payment_modal_state.dart';
import '../../domain/quick_cash.dart';
import '../../domain/transaction.dart';
import 'receipt_modal.dart';

/// Payment modal — shown as a modal (bottom-up) from [CartDrawer]'s
/// "Bayar" button. Handles single payment, split payment, Ojol
/// platform+order-number capture, and finalizes the transaction.
class PaymentModal extends ConsumerStatefulWidget {
  const PaymentModal({super.key});

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cartState = ref.read(cartProvider);
    Future.microtask(() => ref.read(paymentModalProvider.notifier).open(orderType: cartState.orderType));
  }

  Future<void> _finalizePayment({
    required CartState cartState,
    required CheckoutTotals totals,
    required PaymentModalState paymentState,
  }) async {
    setState(() => _isSaving = true);

    final isSplit = paymentState.isSplitMode && paymentState.splitPayments.isNotEmpty;
    final totalPaid = isSplit
        ? paymentState.splitPayments.fold<int>(0, (sum, p) => sum + p.amount)
        : paymentState.amountPaid;
    final change = totalPaid > totals.roundedTotal ? totalPaid - totals.roundedTotal : 0;

    final repository = ref.read(posRepositoryProvider);
    final transaction = await repository.saveTransaction(
      status: TransactionStatus.paid,
      orderType: cartState.orderType,
      customerId: cartState.customer?.id,
      customerName: cartState.customer?.name ?? (cartState.guestName.isNotEmpty ? cartState.guestName : null),
      ojolPlatform: cartState.orderType == OrderType.ojol ? paymentState.ojolPlatform : null,
      ojolOrderNumber: cartState.orderType == OrderType.ojol ? paymentState.orderNumber : null,
      items: cartState.cart,
      subtotal: totals.subtotal,
      voucherId: cartState.appliedVoucher?.id,
      voucherCode: cartState.appliedVoucher?.code,
      voucherDiscount: totals.voucherDiscount,
      manualDiscount: cartState.manualDiscount,
      manualDiscountAmount: totals.manualDiscountAmount,
      taxAmount: totals.taxAmount,
      serviceAmount: totals.serviceAmount,
      deliveryFee: totals.deliveryFee,
      roundingAdjustment: totals.roundingAdjustment,
      total: totals.roundedTotal,
      paymentMethodLabel: isSplit ? 'Split Payment' : paymentState.method.label,
      amountPaid: totalPaid,
      changeAmount: change,
      splitPayments: isSplit ? paymentState.splitPayments : const [],
    );

    if (!mounted) return;

    ref.read(cartProvider.notifier).resetDraft();
    ref.read(paymentModalProvider.notifier).close();

    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptModal(transaction: transaction, changeAmount: change),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    const settings = StoreCheckoutSettings();
    final totals = CheckoutCalculator.compute(cartState, settings);
    final paymentState = ref.watch(paymentModalProvider);
    final paymentController = ref.read(paymentModalProvider.notifier);
    final isOjol = cartState.orderType == OrderType.ojol;

    final paidSoFar = paymentState.isSplitMode
        ? paymentState.splitPayments.fold<int>(0, (sum, p) => sum + p.amount)
        : paymentState.amountPaid;
    final remaining = totals.roundedTotal - paidSoFar;
    final change = paidSoFar > totals.roundedTotal ? paidSoFar - totals.roundedTotal : 0;

    final canConfirm = isOjol
        ? true
        : paymentState.isSplitMode
            ? remaining <= 0 && paymentState.splitPayments.isNotEmpty
            : paidSoFar >= totals.roundedTotal;

    // Full-height, matching CartDrawer — still a modal layer (not a page
    // route), just sized to read like the reference design's Checkout
    // screen instead of a half-screen sheet.
    return DraggableScrollableSheet(
      initialChildSize: 1,
      minChildSize: 0.9,
      maxChildSize: 1,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: AppColors.background),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: Text('Pembayaran', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: AppColors.surface,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () {
                                paymentController.close();
                                Navigator.of(context).pop();
                              },
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
                                ),
                                child: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 120),
                    children: [
                      _TotalDueCard(total: totals.roundedTotal),
                      const SizedBox(height: AppSpacing.xl),
                      if (isOjol)
                        _OjolSection(paymentState: paymentState, controller: paymentController)
                      else ...[
                        _SplitModeToggle(paymentState: paymentState, controller: paymentController),
                        const SizedBox(height: AppSpacing.lg),
                        if (paymentState.isSplitMode)
                          _SplitPaymentSection(
                            paymentState: paymentState,
                            controller: paymentController,
                            remaining: remaining,
                          )
                        else
                          _SinglePaymentSection(
                            paymentState: paymentState,
                            controller: paymentController,
                            total: totals.roundedTotal,
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        if (change > 0) _ChangeCard(amount: change),
                      ],
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
                      onPressed: (!canConfirm || _isSaving)
                          ? null
                          : () => _finalizePayment(cartState: cartState, totals: totals, paymentState: paymentState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text('Konfirmasi Pembayaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TotalDueCard extends StatelessWidget {
  final int total;
  const _TotalDueCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.heroGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL TAGIHAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 6),
          Text(formatRupiah(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

/// Payment method picker — full-width rows with a leading icon and
/// trailing chevron, matching the reference design's method-list sheet,
/// rather than the previous 3-up button row. Tapping a row still just
/// calls [onChanged] immediately (no separate confirm step, since there's
/// nothing further to configure per method today).
class _MethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;
  const _MethodSelector({required this.selected, required this.onChanged});

  static const _methods = [PaymentMethod.tunai, PaymentMethod.qris, PaymentMethod.transfer];

  static IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.tunai:
        return Icons.payments_outlined;
      case PaymentMethod.qris:
        return Icons.qr_code_rounded;
      case PaymentMethod.transfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.ojol:
        return Icons.moped_rounded; // unused here (Ojol has its own section) but keeps the switch exhaustive
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Visual-only per reference design — not wired to any action yet.
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: const [
                Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Tambah metode pembayaran baru / hapus metode pembayaran',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        ..._methods.map((m) {
          final isSelected = selected == m;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              onTap: () => onChanged(m),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: isSelected ? AppColors.brand : AppColors.border, width: isSelected ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Icon(_iconFor(m), size: 20, color: isSelected ? AppColors.brand : AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(m.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    Icon(
                      isSelected ? Icons.radio_button_checked_rounded : Icons.chevron_right_rounded,
                      size: isSelected ? 20 : 22,
                      color: isSelected ? AppColors.brand : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SinglePaymentSection extends StatefulWidget {
  final PaymentModalState paymentState;
  final PaymentModalController controller;
  final int total;
  const _SinglePaymentSection({required this.paymentState, required this.controller, required this.total});

  @override
  State<_SinglePaymentSection> createState() => _SinglePaymentSectionState();
}

class _SinglePaymentSectionState extends State<_SinglePaymentSection> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.paymentState.amountPaidText);
  }

  @override
  void didUpdateWidget(covariant _SinglePaymentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paymentState.amountPaidText != _amountController.text) {
      _amountController.text = widget.paymentState.amountPaidText;
      _amountController.selection = TextSelection.collapsed(offset: _amountController.text.length);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickOptions = buildQuickCashOptions(widget.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Metode Pembayaran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        _MethodSelector(
          selected: widget.paymentState.method,
          onChanged: (method) => widget.controller.setMethod(method, total: widget.total),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Jumlah Dibayar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          onChanged: widget.controller.setAmountPaidText,
        ),
        if (widget.paymentState.method == PaymentMethod.tunai) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: quickOptions
                .map((amount) => OutlinedButton(
                      onPressed: () => widget.controller.setAmountPaidText(amount.toString()),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                      ),
                      child: Text(formatRupiah(amount), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _SplitModeToggle extends StatelessWidget {
  final PaymentModalState paymentState;
  final PaymentModalController controller;
  const _SplitModeToggle({required this.paymentState, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('Split Payment', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        Switch(
          value: paymentState.isSplitMode,
          onChanged: controller.toggleSplitMode,
          activeColor: AppColors.brand,
        ),
      ],
    );
  }
}

class _SplitPaymentSection extends StatefulWidget {
  final PaymentModalState paymentState;
  final PaymentModalController controller;
  final int remaining;
  const _SplitPaymentSection({required this.paymentState, required this.controller, required this.remaining});

  @override
  State<_SplitPaymentSection> createState() => _SplitPaymentSectionState();
}

class _SplitPaymentSectionState extends State<_SplitPaymentSection> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.paymentState.amountPaidText);
  }

  @override
  void didUpdateWidget(covariant _SplitPaymentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paymentState.amountPaidText != _amountController.text) {
      _amountController.text = widget.paymentState.amountPaidText;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.paymentState.splitPayments.isNotEmpty) ...[
          ...widget.paymentState.splitPayments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Expanded(child: Text(payment.method.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    Text(formatRupiah(payment.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                      onPressed: () => widget.controller.removeSplitPayment(index),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (widget.remaining > 0) ...[
          Text('Sisa: ${formatRupiah(widget.remaining)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
          const SizedBox(height: AppSpacing.sm),
          _MethodSelector(selected: widget.paymentState.method, onChanged: widget.controller.setMethod),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(prefixText: 'Rp ', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                  onChanged: widget.controller.setAmountPaidText,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: widget.controller.addSplitPayment, child: const Text('Tambah')),
            ],
          ),
        ],
      ],
    );
  }
}

class _OjolSection extends StatefulWidget {
  final PaymentModalState paymentState;
  final PaymentModalController controller;
  const _OjolSection({required this.paymentState, required this.controller});

  @override
  State<_OjolSection> createState() => _OjolSectionState();
}

class _OjolSectionState extends State<_OjolSection> {
  late final TextEditingController _orderNumberController;

  @override
  void initState() {
    super.initState();
    _orderNumberController = TextEditingController(text: widget.paymentState.orderNumber);
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Platform', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: OjolPlatform.values.map((p) {
            final selected = widget.paymentState.ojolPlatform == p;
            return ChoiceChip(
              label: Text(p.label),
              selected: selected,
              onSelected: (_) => widget.controller.setOjolPlatform(p),
              selectedColor: AppColors.brand,
              labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('Nomor Pesanan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _orderNumberController,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(hintText: 'Contoh: SF-12345', border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md))),
          onChanged: widget.controller.setOrderNumber,
        ),
      ],
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final int amount;
  const _ChangeCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.success.withValues(alpha: 0.25))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Kembalian', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
          Text(formatRupiah(amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.success)),
        ],
      ),
    );
  }
}
