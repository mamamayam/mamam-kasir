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

  /// Non-null while this draft represents an edit of an existing `open`
  /// (Diproses) transaction rather than a brand-new order — see
  /// [CartController.loadFromTransaction] and Transaction Detail's
  /// "Edit Pesanan" action. [CartDrawer] uses this to show the "editing
  /// X" banner and change its bottom-bar action from "Bayar" to "Simpan
  /// Perubahan" (an UPDATE of that transaction, not a new INSERT).
  final String? editingTransactionId;

  /// [Transaction.displayNumber] for [editingTransactionId] — carried
  /// alongside the raw ID purely so the edit-mode banner can show the
  /// same friendly order number used everywhere else in the UI (e.g.
  /// "ORD-4F21A9") instead of a raw UUID. Always non-null together with
  /// [editingTransactionId].
  final String? editingDisplayNumber;

  /// Snapshot of the transaction's original customerId/customerName at
  /// the moment [CartController.loadFromTransaction] ran. [CartState]
  /// only tracks a full [Customer] object or a plain [guestName] — it
  /// has no field for "linked to customer X, unchanged" — so without
  /// this snapshot, saving an edit that never touched the customer
  /// section would read `customer == null` and silently overwrite a
  /// real customer link with null. [CartDrawer._saveEdit] falls back to
  /// these when [customer] is null and [guestName] is empty (i.e.
  /// neither was touched during this edit).
  final String? editingOriginalCustomerId;
  final String? editingOriginalCustomerName;

  const CartState({
    this.cart = const [],
    this.customer,
    this.guestName = '',
    this.orderType = OrderType.takeaway,
    this.deliveryFee = 0,
    this.deliveryCourierNote,
    this.appliedVoucher,
    this.manualDiscount = ManualDiscount.none,
    this.editingTransactionId,
    this.editingDisplayNumber,
    this.editingOriginalCustomerId,
    this.editingOriginalCustomerName,
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
    String? editingTransactionId,
    String? editingDisplayNumber,
    bool clearEditingTransactionId = false,
    String? editingOriginalCustomerId,
    String? editingOriginalCustomerName,
  }) {
    return CartState(
      cart: cart ?? this.cart,
      customer: clearCustomer ? null : (customer ?? this.customer),
      guestName: guestName ?? this.guestName,
      orderType: orderType ?? this.orderType,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      appliedVoucher: clearVoucher ? null : (appliedVoucher ?? this.appliedVoucher),
      manualDiscount: manualDiscount ?? this.manualDiscount,
      editingTransactionId: clearEditingTransactionId ? null : (editingTransactionId ?? this.editingTransactionId),
      editingDisplayNumber: clearEditingTransactionId ? null : (editingDisplayNumber ?? this.editingDisplayNumber),
      editingOriginalCustomerId:
          clearEditingTransactionId ? null : (editingOriginalCustomerId ?? this.editingOriginalCustomerId),
      editingOriginalCustomerName:
          clearEditingTransactionId ? null : (editingOriginalCustomerName ?? this.editingOriginalCustomerName),
    );
  }

  bool get isEditingExisting => editingTransactionId != null;

  static const empty = CartState();
}
