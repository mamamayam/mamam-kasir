/// Order type — matches the reference app's four types exactly.
enum OrderType { takeaway, dineIn, delivery, ojol }

extension OrderTypeX on OrderType {
  String get label {
    switch (this) {
      case OrderType.takeaway:
        return 'Takeaway';
      case OrderType.dineIn:
        return 'Dine-in';
      case OrderType.delivery:
        return 'Delivery';
      case OrderType.ojol:
        return 'Ojol';
    }
  }
}

enum ManualDiscountType { percent, fixed }

class ManualDiscount {
  final ManualDiscountType type;
  final int value;

  const ManualDiscount({required this.type, required this.value});

  static const none = ManualDiscount(type: ManualDiscountType.fixed, value: 0);
}

/// Payment method for a single (non-split) payment, or one leg of a
/// split payment.
enum PaymentMethod { tunai, qris, transfer, ojol }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.tunai:
        return 'Tunai';
      case PaymentMethod.qris:
        return 'QRIS';
      case PaymentMethod.transfer:
        return 'Transfer';
      case PaymentMethod.ojol:
        return 'Ojol';
    }
  }
}

/// One leg of a split payment (e.g. "paid 20000 in Tunai, then 15000 in
/// QRIS").
class SplitPaymentEntry {
  final PaymentMethod method;
  final int amount;

  const SplitPaymentEntry({required this.method, required this.amount});
}

/// Ojol delivery-platform app — Shopeefood/Grabfood/Gofood, matching the
/// reference app's options.
enum OjolPlatform { shopeefood, grabfood, gofood }

extension OjolPlatformX on OjolPlatform {
  String get label {
    switch (this) {
      case OjolPlatform.shopeefood:
        return 'Shopeefood';
      case OjolPlatform.grabfood:
        return 'Grabfood';
      case OjolPlatform.gofood:
        return 'Gofood';
    }
  }
}
