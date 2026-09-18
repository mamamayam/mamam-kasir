/// One outlet (cabang/toko).
///
/// [isActive] is an operational on/off for the outlet, NOT a soft
/// delete: an inactive branch keeps every transaction, expense and
/// report row it ever produced. Same Nonaktif semantics the PRD applies
/// to menu masters — "master data used by history cannot hard-delete;
/// use Nonaktif".
class Cabang {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final int sortOrder;

  const Cabang({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
    this.sortOrder = 0,
  });

  factory Cabang.fromRow(Map<String, Object?> row) {
    return Cabang(
      id: row['id'] as String,
      name: row['name'] as String,
      address: row['address'] as String?,
      phone: row['phone'] as String?,
      isActive: (row['is_active'] as int? ?? 1) == 1,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  /// Phone shown as-is when it's already in `+62` form, otherwise
  /// untouched. Deliberately NOT reformatted to the customer-phone rule
  /// ("display starting 08, grouped every four digits") — that rule is
  /// specified for the Customer module, and a branch's contact number
  /// isn't a customer phone.
  String get displayPhone => (phone ?? '').trim();

  bool get hasPhone => displayPhone.isNotEmpty;

  String get displayAddress => (address ?? '').trim();

  bool get hasAddress => displayAddress.isNotEmpty;
}

/// Aggregate shown in the three cards at the top of Manajemen Cabang.
class CabangSummary {
  final int maxBranches;
  final int totalBranches;
  final int activeBranches;

  const CabangSummary({
    required this.maxBranches,
    required this.totalBranches,
    required this.activeBranches,
  });

  bool get isAtLimit => totalBranches >= maxBranches;

  static const empty = CabangSummary(maxBranches: kDefaultMaxBranches, totalBranches: 0, activeBranches: 0);
}

/// Ceiling shown as "Maks Toko".
///
/// UNSPECIFIED by design: the PRD has no subscription/plan tiering, so
/// this is a single constant rather than an invented billing rule. The
/// screen reads it from here and disables "+" once the ceiling is hit,
/// which reproduces the reference screenshot's behaviour (Maks Toko 1,
/// Toko 1, premium badge on the add button) without pretending a plan
/// system exists. When plans are actually specified, replace this
/// constant with a real lookup — nothing else needs to move.
const int kDefaultMaxBranches = 1;
