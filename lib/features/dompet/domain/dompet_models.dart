/// A cash location — Store Cash/Dompet, or a courier. Per PRD §3,
/// Kasbon/Staff Debt is deliberately NOT a cash location; it's a staff
/// liability tracked separately in [Kasbon].
enum CashLocationType { store, courier }

class CashLocation {
  final String id;
  final CashLocationType type;
  final String name;
  final String? staffId; // null until the Staff module exists
  final bool isActive;

  const CashLocation({
    required this.id,
    required this.type,
    required this.name,
    this.staffId,
    required this.isActive,
  });
}

/// Ledger entry types. Matches the PRD's cash-movement vocabulary —
/// note there is deliberately no "will deposit later" type (PRD §17).
enum CashMovementType {
  opening,
  cashSale, // Store Cash or a courier location receiving payment from a sale
  courierDeposit, // Courier -> Store Cash ("Sudah Disetor")
  convertToKasbon, // Courier -> leaves the cash ledger, becomes Staff Debt
  expense,
  adjustment,
}

/// One immutable cash-movement ledger row. Never edited or deleted —
/// corrections are new adjustment movements, per PRD §26.
class CashMovement {
  final String id;
  final CashMovementType type;
  final String? fromLocationId; // null = cash entering the ledger (e.g. opening, a sale)
  final String? toLocationId; // null = cash leaving the ledger (e.g. convert_to_kasbon)
  final int amount;
  final String? referenceTransactionId;
  final String? referenceKasbonId;
  final String? reason;
  final DateTime createdAt;
  final String? createdBy; // null until Auth exists

  const CashMovement({
    required this.id,
    required this.type,
    this.fromLocationId,
    this.toLocationId,
    required this.amount,
    this.referenceTransactionId,
    this.referenceKasbonId,
    this.reason,
    required this.createdAt,
    this.createdBy,
  });
}

enum KasbonStatus { outstanding, partiallyPaid, paid }

/// Staff debt created by "Jadikan Kasbon". Per PRD §9, status/
/// remaining balance only change via explicit repayment records — never
/// auto-marked paid just by being referenced elsewhere.
class Kasbon {
  final String id;
  final String? staffId; // null until Staff module exists
  final String courierLocationId;
  final String staffName;
  final int amount;
  final int remainingBalance;
  final String source;
  final KasbonStatus status;
  final DateTime createdAt;
  final String? createdBy;
  final List<KasbonRepayment> repayments;

  const Kasbon({
    required this.id,
    this.staffId,
    required this.courierLocationId,
    required this.staffName,
    required this.amount,
    required this.remainingBalance,
    required this.source,
    required this.status,
    required this.createdAt,
    this.createdBy,
    this.repayments = const [],
  });
}

class KasbonRepayment {
  final String id;
  final String kasbonId;
  final int amount;
  final String? note;
  final DateTime createdAt;
  final String? createdBy;

  const KasbonRepayment({
    required this.id,
    required this.kasbonId,
    required this.amount,
    this.note,
    required this.createdAt,
    this.createdBy,
  });
}

/// A cash location with its computed balance (SUM of movements — never
/// a stored/mutated field, per PRD's core ledger principle).
class CashLocationBalance {
  final CashLocation location;
  final int balance;

  const CashLocationBalance({required this.location, required this.balance});
}

/// Top-level Dompet summary shown on the main page: Uang di Dompet /
/// Uang di Kurir / Kasbon Staff — kept as three separate figures per
/// PRD §23 ("Jangan menjumlahkan kategori tersebut secara sembarangan").
class DompetSummary {
  final int storeCashBalance;
  final int totalCourierOutstanding;
  final int totalKasbonOutstanding;
  final List<CashLocationBalance> courierBalances;

  const DompetSummary({
    required this.storeCashBalance,
    required this.totalCourierOutstanding,
    required this.totalKasbonOutstanding,
    required this.courierBalances,
  });
}
