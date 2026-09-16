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
///
/// IMPORTANT: the DB column stores snake_case strings (see the
/// `cash_movements.type` comment in app_database.dart), which do NOT
/// match Dart's enum `.name` for the multi-word members (e.g.
/// `cashSale.name == 'cashSale'`, not `'cash_sale'`). Always read/write
/// this column via [dbValue]/[fromDbValue] — never `.name` or
/// `CashMovementType.values.firstWhere((t) => t.name == ...)` directly.
/// That exact mismatch previously caused every real cash-sale movement
/// to silently fail to parse and fall back to [adjustment], showing up
/// in the UI as a wall of generic "Penyesuaian" entries.
enum CashMovementType {
  opening,
  cashSale, // Store Cash or a courier location receiving payment from a sale
  courierDeposit, // Courier -> Store Cash ("Sudah Disetor")
  convertToKasbon, // Courier -> leaves the cash ledger, becomes Staff Debt
  expense,
  adjustment;

  String get dbValue {
    switch (this) {
      case CashMovementType.opening:
        return 'opening';
      case CashMovementType.cashSale:
        return 'cash_sale';
      case CashMovementType.courierDeposit:
        return 'courier_deposit';
      case CashMovementType.convertToKasbon:
        return 'convert_to_kasbon';
      case CashMovementType.expense:
        return 'expense';
      case CashMovementType.adjustment:
        return 'adjustment';
    }
  }

  static CashMovementType fromDbValue(String value) {
    return CashMovementType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => CashMovementType.adjustment,
    );
  }
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

/// Same snake_case-vs-camelCase trap as [CashMovementType] applies here
/// — `partiallyPaid.name == 'partiallyPaid'`, but the DB column
/// (`kasbon.status` comment in app_database.dart) stores
/// `'partially_paid'`. Always use [dbValue]/[fromDbValue].
enum KasbonStatus {
  outstanding,
  partiallyPaid,
  paid;

  String get dbValue {
    switch (this) {
      case KasbonStatus.outstanding:
        return 'outstanding';
      case KasbonStatus.partiallyPaid:
        return 'partially_paid';
      case KasbonStatus.paid:
        return 'paid';
    }
  }

  static KasbonStatus fromDbValue(String value) {
    return KasbonStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => KasbonStatus.outstanding,
    );
  }
}

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

/// Status of a Dompet closing ("Tutup Dompet"). [overdueClosing] is the
/// PRD-mandated state for a shift/day not closed before midnight — it
/// must never auto-close with guessed numbers, and next-day movements
/// must never be folded into it (PRD's overdue-closing invariant).
enum DompetClosingStatus { closed, overdueClosing }

/// Same snake_case DB convention as the other enums here.
extension DompetClosingStatusDb on DompetClosingStatus {
  String get dbValue => this == DompetClosingStatus.closed ? 'closed' : 'overdue_closing';

  static DompetClosingStatus fromDbValue(String value) =>
      value == 'overdue_closing' ? DompetClosingStatus.overdueClosing : DompetClosingStatus.closed;
}

/// One immutable "Tutup Dompet" closing record for Store Cash.
///
/// NOTE: this app doesn't have a Shift module yet (see [[dompet-prd]] /
/// [[mamam-kasir-flutter]]), so a closing period here is simply "since
/// the previous closing's periodEnd" rather than a formal shift. Once
/// Shift exists, [periodStart]/[periodEnd] are expected to be
/// reconciled against shift_id rather than the previous closing row —
/// the ledger math and the courier-outstanding block below are the
/// part of this that's meant to carry over unchanged.
///
/// Per PRD: Expected Cash = Opening + Cash Sales + Courier Deposits -
/// Cash Expenses (courier outstanding is excluded until settled).
/// [countedCash] is what the kasir physically counted; [discrepancy] =
/// countedCash - expectedCash, and is recorded as its own `adjustment`
/// cash movement so the ledger and the physical count reconcile to the
/// same number going forward — this record itself is never edited.
class DompetClosing {
  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int openingBalance;
  final int cashSalesTotal;
  final int courierDepositsTotal;
  final int cashExpensesTotal;
  final int expectedCash;
  final int countedCash;
  final int discrepancy;
  final DompetClosingStatus status;
  final String? note;
  final DateTime createdAt;
  final String? createdBy;

  const DompetClosing({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.cashSalesTotal,
    required this.courierDepositsTotal,
    required this.cashExpensesTotal,
    required this.expectedCash,
    required this.countedCash,
    required this.discrepancy,
    required this.status,
    this.note,
    required this.createdAt,
    this.createdBy,
  });
}

/// A dry-run preview of what closing right now would look like — shown
/// on the Tutup Dompet screen before the kasir commits. Not persisted.
class DompetClosingPreview {
  final DateTime periodStart;
  final int openingBalance;
  final int cashSalesTotal;
  final int courierDepositsTotal;
  final int cashExpensesTotal;
  final int expectedCash;
  final List<CashLocationBalance> outstandingCouriers;

  const DompetClosingPreview({
    required this.periodStart,
    required this.openingBalance,
    required this.cashSalesTotal,
    required this.courierDepositsTotal,
    required this.cashExpensesTotal,
    required this.expectedCash,
    required this.outstandingCouriers,
  });

  /// Per PRD: closing is blocked while any courier holds outstanding
  /// cash — it must be resolved (deposited or converted to kasbon)
  /// first, never carried across the close.
  bool get canClose => outstandingCouriers.isEmpty;
}
