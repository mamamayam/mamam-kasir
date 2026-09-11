import 'cart_item.dart';
import 'customer.dart';
import 'order_models.dart';
import 'voucher.dart';

/// Store-wide settings affecting checkout math — tax/service/rounding.
/// Kept minimal for this vertical slice; a real Settings screen would
/// own and persist these later.
class StoreCheckoutSettings {
  final int taxRatePercent;
  final int serviceChargePercent;
  final RoundingMode roundingMode;

  const StoreCheckoutSettings({
    this.taxRatePercent = 0,
    this.serviceChargePercent = 0,
    this.roundingMode = RoundingMode.none,
  });
}

enum RoundingMode { none, nearest500 }

/// The full draft-transaction state — same shape as the reference app's
/// persisted Zustand slice (cart, customer, order type, delivery,
/// voucher, manual discount) plus the in-progress payment form.
class CartState {
  final List<CartItem> cart;
  final Customer? customer;
  final String guestName;
  final OrderType orderType;
  final int deliveryFee;
  final String? deliveryCourierNote; // kept as a free note only — courier cash-holding logic deferred
  final Voucher? appliedVoucher;
  final ManualDiscount manualDiscount;

  const CartState({
    this.cart = const [],
    this.customer,
    this.guestName = '',
    this.orderType = OrderType.takeaway,
    this.deliveryFee = 0,
    this.deliveryCourierNote,
    this.appliedVoucher,
    this.manualDiscount = ManualDiscount.none,
  });

  CartState copyWith({
    List<CartItem>? cart,
    Customer? customer,
    bool clearCustomer = false,
    String? guestName,
    OrderType? orderType,
    int? deliveryFee,
    Voucher? appliedVoucher,
    bool clearVoucher = false,
    ManualDiscount? manualDiscount,
  }) {
    return CartState(
      cart: cart ?? this.cart,
      customer: clearCustomer ? null : (customer ?? this.customer),
      guestName: guestName ?? this.guestName,
      orderType: orderType ?? this.orderType,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      appliedVoucher: clearVoucher ? null : (appliedVoucher ?? this.appliedVoucher),
      manualDiscount: manualDiscount ?? this.manualDiscount,
    );
  }

  static const empty = CartState();
}
