import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../menu_management/domain/menu_management_models.dart';
import '../domain/cart_item.dart';
import '../domain/cart_state.dart';
import '../domain/checkout_calculator.dart';
import '../domain/customer.dart';
import '../domain/order_models.dart';
import '../domain/transaction.dart';
import 'pos_repository.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository());

/// NOTE: not persisted across app restarts yet (the reference app's
/// draft survives via Zustand's `persist` + localStorage). Local
/// persistence for the cart draft is a follow-up once this checkout
/// flow itself is verified working — flagged here rather than silently
/// left out.
final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController(ref.watch(posRepositoryProvider));
});

class CartController extends StateNotifier<CartState> {
  final PosRepository _repository;

  CartController(this._repository) : super(CartState.empty);

  // --- Cart item actions ---

  void addToCart(MenuItem menu, Map<String, List<String>> selectedOptions, List<VariantGroup> variantGroups, {int quantity = 1}) {
    final cartItemId = CartItemBuilder.buildCartItemId(menu.id, selectedOptions);
    final existingIndex = state.cart.indexWhere((i) => i.cartItemId == cartItemId);

    if (existingIndex != -1) {
      final updated = [...state.cart];
      updated[existingIndex] = updated[existingIndex].copyWith(qty: updated[existingIndex].qty + quantity);
      state = state.copyWith(cart: updated);
      return;
    }

    final newItem = CartItemBuilder.build(
      menu: menu,
      selectedOptions: selectedOptions,
      variantGroups: variantGroups,
      existingQty: quantity - 1,
    );
    state = state.copyWith(cart: [...state.cart, newItem]);
  }

  void updateQty(String cartItemId, int delta) {
    final updated = state.cart
        .map((item) {
          if (item.cartItemId != cartItemId) return item;
          final newQty = item.qty + delta;
          return newQty > 0 ? item.copyWith(qty: newQty) : null;
        })
        .whereType<CartItem>()
        .toList();
    state = state.copyWith(cart: updated);
  }

  void setQty(String cartItemId, int qty) {
    if (qty <= 0) {
      removeItem(cartItemId);
      return;
    }
    final updated = state.cart.map((item) => item.cartItemId == cartItemId ? item.copyWith(qty: qty) : item).toList();
    state = state.copyWith(cart: updated);
  }

  void updateNote(String cartItemId, String note) {
    final updated = state.cart.map((item) => item.cartItemId == cartItemId ? item.copyWith(note: note) : item).toList();
    state = state.copyWith(cart: updated);
  }

  void removeItem(String cartItemId) {
    state = state.copyWith(cart: state.cart.where((i) => i.cartItemId != cartItemId).toList());
  }

  // --- Customer ---

  void setCustomer(Customer customer) {
    state = state.copyWith(customer: customer, guestName: '');
  }

  void setGuestName(String name) {
    state = state.copyWith(guestName: name, clearCustomer: true);
  }

  void clearCustomer() {
    state = state.copyWith(clearCustomer: true, guestName: '');
  }

  Future<Customer> createAndSetCustomer({required String name, String? phone}) async {
    final customer = await _repository.createCustomer(name: name, phone: phone);
    setCustomer(customer);
    return customer;
  }

  // --- Order type & delivery ---

  void setOrderType(OrderType type) {
    if (type == OrderType.ojol) {
      // Reset discounts/voucher on Ojol, matching the reference app —
      // Ojol orders don't carry manual discounts or vouchers.
      state = state.copyWith(
        orderType: type,
        deliveryFee: 0,
        clearVoucher: true,
        manualDiscount: ManualDiscount.none,
      );
      return;
    }

    state = state.copyWith(
      orderType: type,
      deliveryFee: type == OrderType.delivery ? state.deliveryFee : 0,
    );
  }

  void setDeliveryFee(int fee) {
    state = state.copyWith(deliveryFee: fee);
  }

  // --- Voucher & manual discount ---

  Future<bool> applyVoucherCode(String code) async {
    final voucher = await _repository.findVoucherByCode(code.toUpperCase());
    if (voucher == null) return false;
    if (CheckoutCalculator.subtotal(state) < voucher.minPurchase) return false;
    state = state.copyWith(appliedVoucher: voucher);
    return true;
  }

  void clearVoucher() {
    state = state.copyWith(clearVoucher: true);
  }

  void setManualDiscount(ManualDiscount discount) {
    state = state.copyWith(manualDiscount: discount);
  }

  // --- Reset ---

  void resetDraft() {
    state = CartState.empty;
  }

  /// "Edit Pesanan" entry point — replaces whatever draft is currently
  /// in [cartProvider] with a copy of an existing `open` (Diproses)
  /// transaction's items/order type/delivery fee/manual discount, and
  /// marks the draft as editing that transaction via
  /// [CartState.editingTransactionId]. [CartDrawer] reads that flag to
  /// show the "editing X" banner and change its save action to an
  /// UPDATE (see [HistoryRepository.updateOpenTransaction]) instead of
  /// a new checkout.
  ///
  /// Note: [Transaction.customerId]/[voucherId] are stored as plain
  /// IDs/codes on the transaction row, not full snapshot objects, so
  /// this does not re-populate [CartState.customer]/[appliedVoucher] —
  /// only the guest name (when there was no linked customer) carries
  /// over. Re-attaching a specific customer or voucher, if needed, is a
  /// manual step in the cart itself after loading.
  void loadFromTransaction(Transaction transaction) {
    state = CartState(
      cart: transaction.items,
      guestName: transaction.customerId == null ? (transaction.customerName ?? '') : '',
      orderType: transaction.orderType,
      deliveryFee: transaction.deliveryFee,
      manualDiscount: transaction.manualDiscount ?? ManualDiscount.none,
      editingTransactionId: transaction.id,
      editingDisplayNumber: transaction.displayNumber,
      editingOriginalCustomerId: transaction.customerId,
      editingOriginalCustomerName: transaction.customerName,
    );
  }
}
