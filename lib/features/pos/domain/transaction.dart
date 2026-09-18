import 'cart_item.dart';
import 'order_models.dart';

enum TransactionStatus { open, paid, canceled }

/// A completed (or still-open/unpaid) transaction. This is a snapshot —
/// per PRD ("Historical data survives master changes"), nothing here is
/// recomputed later from current menu prices, settings, or vouchers.
class Transaction {
  final String id;
  final String displayNumber;
  final TransactionStatus status;
  final OrderType orderType;
  final String? customerId;
  final String? customerName;
  final OjolPlatform? ojolPlatform;
  final String? ojolOrderNumber;
  final List<CartItem> items;

  final int subtotal;
  final String? voucherId;
  final String? voucherCode;
  final int voucherDiscount;
  final ManualDiscount? manualDiscount;
  final int manualDiscountAmount;
  final int taxAmount;
  final int serviceAmount;
  final int deliveryFee;
  final int roundingAdjustment;
  final int total;

  final String? paymentMethodLabel; // 'Tunai' | 'QRIS' | 'Transfer' | 'Ojol' | 'Split Payment'
  final int? amountPaid;
  final int? changeAmount;
  final List<SplitPaymentEntry> splitPayments;

  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? canceledAt;
  final String? cancelReason;

  const Transaction({
    required this.id,
    required this.displayNumber,
    required this.status,
    required this.orderType,
    this.customerId,
    this.customerName,
    this.ojolPlatform,
    this.ojolOrderNumber,
    required this.items,
    required this.subtotal,
    this.voucherId,
    this.voucherCode,
    required this.voucherDiscount,
    this.manualDiscount,
    required this.manualDiscountAmount,
    required this.taxAmount,
    required this.serviceAmount,
    required this.deliveryFee,
    required this.roundingAdjustment,
    required this.total,
    this.paymentMethodLabel,
    this.amountPaid,
    this.changeAmount,
    this.splitPayments = const [],
    required this.createdAt,
    this.paidAt,
    this.canceledAt,
    this.cancelReason,
  });

  bool get isCanceled => status == TransactionStatus.canceled;

  /// "Diproses" in the UI — not yet paid, still editable, excluded from
  /// Dompet/Dashboard/Laporan until [HistoryRepository.completeTransaction]
  /// moves it to [isPaid].
  bool get isOpen => status == TransactionStatus.open;

  bool get isPaid => status == TransactionStatus.paid;

  int get hppTotal => items.fold(0, (sum, item) => sum + (item.hpp * item.qty));
  int get totalQty => items.fold(0, (sum, item) => sum + item.qty);
}
