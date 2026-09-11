import 'order_models.dart';

enum PaymentStatus { pending, completed }

/// In-progress payment form state. Kept as its own provider (not part
/// of [CartState]) — mirrors the reference app's rationale for putting
/// this in a separate Zustand slice: typing an amount shouldn't
/// rebuild every widget watching the cart.
class PaymentModalState {
  final bool isOpen;
  final bool isSplitMode;
  final List<SplitPaymentEntry> splitPayments;
  final PaymentMethod method;
  final String amountPaidText;
  final PaymentStatus status;
  final OjolPlatform? ojolPlatform;
  final String orderNumber;

  const PaymentModalState({
    this.isOpen = false,
    this.isSplitMode = false,
    this.splitPayments = const [],
    this.method = PaymentMethod.tunai,
    this.amountPaidText = '',
    this.status = PaymentStatus.pending,
    this.ojolPlatform,
    this.orderNumber = '',
  });

  int get amountPaid => int.tryParse(amountPaidText) ?? 0;

  PaymentModalState copyWith({
    bool? isOpen,
    bool? isSplitMode,
    List<SplitPaymentEntry>? splitPayments,
    PaymentMethod? method,
    String? amountPaidText,
    PaymentStatus? status,
    OjolPlatform? ojolPlatform,
    String? orderNumber,
  }) {
    return PaymentModalState(
      isOpen: isOpen ?? this.isOpen,
      isSplitMode: isSplitMode ?? this.isSplitMode,
      splitPayments: splitPayments ?? this.splitPayments,
      method: method ?? this.method,
      amountPaidText: amountPaidText ?? this.amountPaidText,
      status: status ?? this.status,
      ojolPlatform: ojolPlatform ?? this.ojolPlatform,
      orderNumber: orderNumber ?? this.orderNumber,
    );
  }

  static const closed = PaymentModalState();
}
