import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_models.dart';
import '../domain/payment_modal_state.dart';

final paymentModalProvider = StateNotifierProvider.autoDispose<PaymentModalController, PaymentModalState>((ref) {
  return PaymentModalController();
});

class PaymentModalController extends StateNotifier<PaymentModalState> {
  PaymentModalController() : super(PaymentModalState.closed);

  void open({required OrderType orderType}) {
    state = PaymentModalState(
      isOpen: true,
      method: orderType == OrderType.ojol ? PaymentMethod.ojol : PaymentMethod.tunai,
    );
  }

  void close() {
    state = PaymentModalState.closed;
  }

  /// Sets the selected payment method. When [total] is passed (i.e. this
  /// is the single, non-split payment section) and [method] is QRIS or
  /// Transfer, the amount field is auto-filled with the full [total] —
  /// those methods are assumed paid in full up front, unlike Tunai which
  /// still needs a typed/quick-cash amount. Split-payment legs call this
  /// without [total], so auto-fill never applies there.
  void setMethod(PaymentMethod method, {int? total}) {
    final shouldAutoFillFull = total != null && (method == PaymentMethod.qris || method == PaymentMethod.transfer);
    state = state.copyWith(
      method: method,
      status: PaymentStatus.pending,
      amountPaidText: shouldAutoFillFull ? total.toString() : state.amountPaidText,
    );
  }

  void setAmountPaidText(String text) {
    state = state.copyWith(amountPaidText: text);
  }

  void setOjolPlatform(OjolPlatform platform) {
    state = state.copyWith(ojolPlatform: platform);
  }

  void setOrderNumber(String number) {
    state = state.copyWith(orderNumber: number);
  }

  /// Records which Dompet cash location is holding the cash for this
  /// payment (Store Cash, or a specific courier) — see
  /// [[dompet-prd]]. Only meaningful for cash payments on Delivery/Ojol
  /// orders; the UI only shows this picker in that case.
  void setCashLocation(String locationId) {
    state = state.copyWith(cashLocationId: locationId);
  }

  void markCompleted() {
    state = state.copyWith(status: PaymentStatus.completed);
  }

  void toggleSplitMode(bool enabled) {
    state = state.copyWith(
      isSplitMode: enabled,
      splitPayments: enabled ? state.splitPayments : [],
      amountPaidText: '',
    );
  }

  void addSplitPayment() {
    final amount = state.amountPaid;
    if (amount <= 0) return;
    state = state.copyWith(
      splitPayments: [...state.splitPayments, SplitPaymentEntry(method: state.method, amount: amount)],
      amountPaidText: '',
      method: PaymentMethod.tunai,
    );
  }

  void removeSplitPayment(int index) {
    final updated = [...state.splitPayments]..removeAt(index);
    state = state.copyWith(splitPayments: updated);
  }
}
