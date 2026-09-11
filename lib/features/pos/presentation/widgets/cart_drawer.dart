import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../application/cart_provider.dart';
import '../../application/pos_catalog_provider.dart';
import '../../domain/cart_item.dart';
import '../../domain/cart_state.dart';
import '../../domain/checkout_calculator.dart';
import '../../domain/customer.dart';
import '../../domain/order_models.dart';
import 'customer_picker_sheet.dart';
import 'payment_modal.dart';

/// Cart drawer — shown as a modal (bottom-up) from the Kasir screen.
/// Customer/order-type/delivery/voucher/discount editing, item list with
/// qty controls, and the entry point into [PaymentModal].
class CartDrawer extends ConsumerWidget {
  const CartDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final cartController = ref.read(cartProvider.notifier);
    const settings = StoreCheckoutSettings(); // placeholder default until Settings feature lands
    final totals = CheckoutCalculator.compute(cartState, settings);
    final isOjol = cartState.orderType == OrderType.ojol;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
                    const Text('Keranjang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              if (cartState.cart.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Keranjang kosong', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                    children: [
                      _CustomerSection(cartState: cartState),
                      const SizedBox(height: AppSpacing.lg),
                      _OrderTypeSection(cartState: cartState, controller: cartController),
                      if (cartState.orderType == OrderType.delivery) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _DeliveryFeeField(cartState: cartState, controller: cartController),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _CartItemsList(items: cartState.cart, controller: cartController),
                      if (!isOjol) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _VoucherAndDiscountSection(cartState: cartState, controller: cartController),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _TotalsSummary(totals: totals),
                    ],
                  ),
                ),
              _BottomBar(
                total: totals.roundedTotal,
                enabled: cartState.cart.isNotEmpty,
                onCheckout: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const PaymentModal(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerSection extends ConsumerWidget {
  final CartState cartState;
  const _CustomerSection({required this.cartState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = cartState.customer?.name ?? (cartState.guestName.isNotEmpty ? cartState.guestName : 'Pelanggan Umum');

    return _SectionCard(
      child: InkWell(
        onTap: () async {
          final customers = ref.read(posCatalogProvider).customers;
          final result = await showModalBottomSheet<Customer>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => CustomerPickerSheet(customers: customers),
          );
          if (result != null) {
            ref.read(cartProvider.notifier).setCustomer(result);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Icon(Icons.person_rounded, size: 18, color: AppColors.brand),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OrderTypeSection extends StatelessWidget {
  final CartState cartState;
  final CartController controller;
  const _OrderTypeSection({required this.cartState, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: OrderType.values.map((type) {
        final selected = cartState.orderType == type;
        return ChoiceChip(
          label: Text(type.label),
          selected: selected,
          onSelected: (_) => controller.setOrderType(type),
          selectedColor: AppColors.brand,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surface,
          side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        );
      }).toList(),
    );
  }
}

/// Preset ongkir amounts shown as quick-pick chips. `null` here
/// represents the "Custom" option (free-form amount via text field),
/// distinct from 0 which is a real "Gratis" (free) delivery fee.
const List<int?> _deliveryFeePresets = [0, 3000, 4000, 5000, null];

class _DeliveryFeeField extends StatefulWidget {
  final CartState cartState;
  final CartController controller;
  const _DeliveryFeeField({required this.cartState, required this.controller});

  @override
  State<_DeliveryFeeField> createState() => _DeliveryFeeFieldState();
}

class _DeliveryFeeFieldState extends State<_DeliveryFeeField> {
  late final TextEditingController _customController;
  // Starts true whenever the current fee doesn't match any preset, so a
  // fee restored from a draft (or set before this widget existed) still
  // shows correctly instead of silently snapping to a preset.
  late bool _isCustom = !_deliveryFeePresets.contains(widget.cartState.deliveryFee);

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(
      text: _isCustom && widget.cartState.deliveryFee > 0 ? widget.cartState.deliveryFee.toString() : '',
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(int? preset) {
    if (preset == null) {
      // "Custom" tapped — reveal the field; don't change the fee until
      // the user actually types an amount.
      setState(() => _isCustom = true);
      return;
    }
    setState(() => _isCustom = false);
    _customController.clear();
    widget.controller.setDeliveryFee(preset);
  }

  @override
  Widget build(BuildContext context) {
    final currentFee = widget.cartState.deliveryFee;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.moped_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              const Text('Ongkir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _deliveryFeePresets.map((preset) {
              final selected = preset == null ? _isCustom : (!_isCustom && currentFee == preset);
              final label = preset == null ? 'Custom' : (preset == 0 ? 'Gratis' : formatRupiah(preset));
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => _selectPreset(preset),
                selectedColor: AppColors.brand,
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
                backgroundColor: AppColors.background,
                side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
              );
            }).toList(),
          ),
          if (_isCustom) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _customController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                isDense: true,
                hintText: 'Jumlah ongkir',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
              onChanged: (v) => widget.controller.setDeliveryFee(int.tryParse(v) ?? 0),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemsList extends StatelessWidget {
  final List<CartItem> items;
  final CartController controller;
  const _CartItemsList({required this.items, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => _CartItemTile(item: item, controller: controller)).toList(),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final CartController controller;
  const _CartItemTile({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: _SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  if (item.variantName != null) ...[
                    const SizedBox(height: 2),
                    Text(item.variantName!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Text(formatRupiah(item.price), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                ],
              ),
            ),
            _QtyStepper(
              qty: item.qty,
              onDecrement: () => controller.updateQty(item.cartItemId, -1),
              onIncrement: () => controller.updateQty(item.cartItemId, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtyStepper({required this.qty, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: Icons.remove_rounded, onTap: onDecrement),
        SizedBox(
          width: 28,
          child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ),
        _StepperButton(icon: Icons.add_rounded, onTap: onIncrement),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 28, height: 28, child: Icon(icon, size: 15, color: AppColors.textPrimary)),
      ),
    );
  }
}

class _VoucherAndDiscountSection extends StatefulWidget {
  final CartState cartState;
  final CartController controller;
  const _VoucherAndDiscountSection({required this.cartState, required this.controller});

  @override
  State<_VoucherAndDiscountSection> createState() => _VoucherAndDiscountSectionState();
}

class _VoucherAndDiscountSectionState extends State<_VoucherAndDiscountSection> {
  final _voucherController = TextEditingController();
  final _manualDiscountController = TextEditingController();
  bool _voucherError = false;
  ManualDiscountType _manualType = ManualDiscountType.fixed;

  @override
  void initState() {
    super.initState();
    _manualType = widget.cartState.manualDiscount.type;
    if (widget.cartState.manualDiscount.value > 0) {
      _manualDiscountController.text = widget.cartState.manualDiscount.value.toString();
    }
  }

  @override
  void dispose() {
    _voucherController.dispose();
    _manualDiscountController.dispose();
    super.dispose();
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;
    final success = await widget.controller.applyVoucherCode(code);
    setState(() => _voucherError = !success);
    if (success) _voucherController.clear();
  }

  void _applyManualDiscount() {
    final value = int.tryParse(_manualDiscountController.text.trim()) ?? 0;
    widget.controller.setManualDiscount(ManualDiscount(type: _manualType, value: value));
  }

  @override
  Widget build(BuildContext context) {
    final voucher = widget.cartState.appliedVoucher;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voucher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          if (voucher != null)
            Row(
              children: [
                Expanded(
                  child: Text(voucher.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.brand)),
                ),
                TextButton(
                  onPressed: widget.controller.clearVoucher,
                  child: const Text('Hapus', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucherController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Kode voucher',
                      isDense: true,
                      errorText: _voucherError ? 'Voucher tidak valid' : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(onPressed: _applyVoucher, child: const Text('Pakai')),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Diskon Manual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _DiscountTypeToggle(
                type: _manualType,
                onChanged: (t) {
                  setState(() => _manualType = t);
                  _applyManualDiscount();
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _manualDiscountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  onChanged: (_) => _applyManualDiscount(),
                  decoration: InputDecoration(
                    hintText: _manualType == ManualDiscountType.percent ? '0%' : 'Rp 0',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscountTypeToggle extends StatelessWidget {
  final ManualDiscountType type;
  final ValueChanged<ManualDiscountType> onChanged;
  const _DiscountTypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(label: '%', selected: type == ManualDiscountType.percent, onTap: () => onChanged(ManualDiscountType.percent)),
          _ToggleOption(label: 'Rp', selected: type == ManualDiscountType.fixed, onTap: () => onChanged(ManualDiscountType.fixed)),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected ? AppColors.brand : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _TotalsSummary extends StatelessWidget {
  final CheckoutTotals totals;
  const _TotalsSummary({required this.totals});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', value: totals.subtotal),
          if (totals.voucherDiscount > 0) _TotalRow(label: 'Diskon Voucher', value: -totals.voucherDiscount),
          if (totals.manualDiscountAmount > 0) _TotalRow(label: 'Diskon Manual', value: -totals.manualDiscountAmount),
          if (totals.taxAmount > 0) _TotalRow(label: 'Pajak', value: totals.taxAmount),
          if (totals.serviceAmount > 0) _TotalRow(label: 'Service', value: totals.serviceAmount),
          if (totals.deliveryFee > 0) _TotalRow(label: 'Ongkir', value: totals.deliveryFee),
          const Divider(height: 20),
          _TotalRow(label: 'TOTAL', value: totals.roundedTotal, isBold: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final int value;
  final bool isBold;
  const _TotalRow({required this.label, required this.value, this.isBold = false});

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

class _BottomBar extends StatelessWidget {
  final int total;
  final bool enabled;
  final VoidCallback onCheckout;
  const _BottomBar({required this.total, required this.enabled, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onCheckout : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            elevation: 0,
          ),
          child: Text('Bayar • ${formatRupiah(total)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
