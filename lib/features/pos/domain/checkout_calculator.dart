import 'dart:math';

import 'cart_state.dart';
import 'order_models.dart';
import 'voucher.dart';

/// All derived checkout amounts for the current cart + settings. A
/// direct port of the reference app's `getSubtotal`/`getDiscount`/
/// `getTaxAmount`/`getServiceChargeAmount`/`getTotal`/`getRoundedTotal`/
/// `getRoundingAdjustment` chain (App.jsx), same formula order:
///
///   taxableAmount = max(0, subtotal - voucherDiscount - manualDiscount)
///   tax = taxableAmount * taxRate%
///   service = taxableAmount * serviceRate%
///   total = max(0, taxableAmount + tax + service + deliveryFee)
///   roundedTotal = rounding applied to total
///
/// NOTE: loyalty points are intentionally absent (per PRD, points are no
/// longer used) — the reference app's `getPointDiscount` step is
/// dropped from this chain.
class CheckoutTotals {
  final int subtotal;
  final int voucherDiscount;
  final int manualDiscountAmount;
  final int taxableAmount;
  final int taxAmount;
  final int serviceAmount;
  final int deliveryFee;
  final int total; // pre-rounding
  final int roundedTotal;
  final int roundingAdjustment;

  const CheckoutTotals({
    required this.subtotal,
    required this.voucherDiscount,
    required this.manualDiscountAmount,
    required this.taxableAmount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.deliveryFee,
    required this.total,
    required this.roundedTotal,
    required this.roundingAdjustment,
  });
}

class CheckoutCalculator {
  static int subtotal(CartState state) {
    return state.cart.fold(0, (sum, item) => sum + item.lineTotal);
  }

  static int voucherDiscount(CartState state) {
    final voucher = state.appliedVoucher;
    if (voucher == null) return 0;
    final sub = subtotal(state);
    if (sub < voucher.minPurchase) return 0;
    if (voucher.discountType == VoucherDiscountType.percent) {
      return (sub * voucher.discountValue / 100).round();
    }
    return voucher.discountValue;
  }

  static int manualDiscountAmount(CartState state) {
    final discount = state.manualDiscount;
    if (discount.value <= 0) return 0;
    if (discount.type == ManualDiscountType.percent) {
      return (subtotal(state) * discount.value / 100).round();
    }
    return discount.value;
  }

  static int taxableAmount(CartState state) {
    final sub = subtotal(state);
    final taxable = sub - voucherDiscount(state) - manualDiscountAmount(state);
    return max(0, taxable);
  }

  static int taxAmount(CartState state, StoreCheckoutSettings settings) {
    return (taxableAmount(state) * settings.taxRatePercent / 100).round();
  }

  static int serviceAmount(CartState state, StoreCheckoutSettings settings) {
    return (taxableAmount(state) * settings.serviceChargePercent / 100).round();
  }

  static int total(CartState state, StoreCheckoutSettings settings) {
    final deliveryFee = state.orderType == OrderType.delivery ? state.deliveryFee : 0;
    final t = taxableAmount(state) + taxAmount(state, settings) + serviceAmount(state, settings) + deliveryFee;
    return max(0, t);
  }

  static int roundedTotal(CartState state, StoreCheckoutSettings settings) {
    final t = total(state, settings);
    switch (settings.roundingMode) {
      case RoundingMode.nearest500:
        return (t / 500).floor() * 500;
      case RoundingMode.none:
        return t;
    }
  }

  static int roundingAdjustment(CartState state, StoreCheckoutSettings settings) {
    return roundedTotal(state, settings) - total(state, settings);
  }

  static CheckoutTotals compute(CartState state, StoreCheckoutSettings settings) {
    final deliveryFee = state.orderType == OrderType.delivery ? state.deliveryFee : 0;
    return CheckoutTotals(
      subtotal: subtotal(state),
      voucherDiscount: voucherDiscount(state),
      manualDiscountAmount: manualDiscountAmount(state),
      taxableAmount: taxableAmount(state),
      taxAmount: taxAmount(state, settings),
      serviceAmount: serviceAmount(state, settings),
      deliveryFee: deliveryFee,
      total: total(state, settings),
      roundedTotal: roundedTotal(state, settings),
      roundingAdjustment: roundingAdjustment(state, settings),
    );
  }
}
