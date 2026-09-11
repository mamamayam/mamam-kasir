/// Code-based discount voucher.
///
/// NOTE: included per explicit user decision overriding AGENTS.md's
/// "active points/vouchers" forbidden-scope rule — see
/// [[mamam-kasir-flutter]] memory notes for the rationale. Loyalty
/// points themselves are NOT implemented (per PRD, points are no
/// longer used).
class Voucher {
  final String id;
  final String code;
  final VoucherDiscountType discountType;
  final int discountValue; // percent (0-100) or fixed Rupiah, per discountType
  final int minPurchase;
  final bool isActive;

  const Voucher({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minPurchase,
    required this.isActive,
  });
}

enum VoucherDiscountType { percent, fixed }
