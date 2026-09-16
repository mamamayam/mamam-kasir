enum ArusKasDirection { pemasukan, pengeluaran }

extension ArusKasDirectionDb on ArusKasDirection {
  String get dbValue => this == ArusKasDirection.pemasukan ? 'pemasukan' : 'pengeluaran';

  static ArusKasDirection fromDbValue(String value) =>
      value == 'pemasukan' ? ArusKasDirection.pemasukan : ArusKasDirection.pengeluaran;
}

/// How an Arus Kas entry is funded. 'cashLocation' means the amount is
/// wired to a real Dompet cash_location (Store Cash or a courier) via a
/// matching cash_movement — Dompet balances and Arus Kas totals stay
/// berkesinambungan (traceable to each other). 'nonCash' (transfer/
/// QRIS/etc.) never touches a physical cash balance and has no
/// cash_movement.
enum ArusKasFundingSource { cashLocation, nonCash }

extension ArusKasFundingSourceDb on ArusKasFundingSource {
  String get dbValue => this == ArusKasFundingSource.cashLocation ? 'cash_location' : 'non_cash';

  static ArusKasFundingSource fromDbValue(String value) =>
      value == 'cash_location' ? ArusKasFundingSource.cashLocation : ArusKasFundingSource.nonCash;
}

/// One Arus Kas (Pemasukan/Pengeluaran) entry.
class ArusKasEntry {
  final String id;
  final ArusKasDirection direction;
  final String category;
  final int amount;
  final DateTime transactionDate;
  final String? sourceLocationId; // null when fundingSource = nonCash
  final String? sourceLocationName; // denormalized for display, joined at read time
  final ArusKasFundingSource fundingSource;
  final String? storeOrSupplierName; // Pengeluaran only
  final String? detail;
  final String? cashMovementId; // null for nonCash entries
  final DateTime createdAt;
  final String? createdBy;

  const ArusKasEntry({
    required this.id,
    required this.direction,
    required this.category,
    required this.amount,
    required this.transactionDate,
    this.sourceLocationId,
    this.sourceLocationName,
    required this.fundingSource,
    this.storeOrSupplierName,
    this.detail,
    this.cashMovementId,
    required this.createdAt,
    this.createdBy,
  });

  /// Label shown in the Sumber Dana field/dropdown — "Non-Tunai" for
  /// non-cash entries, otherwise the cash location's display name.
  String get sourceLabel => fundingSource == ArusKasFundingSource.nonCash ? 'Non-Tunai' : (sourceLocationName ?? 'Dompet Toko');
}

enum ArusKasDateFilter { hariIni, kemarin, bulanIni, bulanKemarin, pilihTanggal }
