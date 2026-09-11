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

  void setMethod(PaymentMethod method) {
    state = state.copyWith(method: method, status: PaymentStatus.pending);
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
