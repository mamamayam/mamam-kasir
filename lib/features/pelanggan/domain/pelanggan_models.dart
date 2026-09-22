/// One purchase line in a customer's history (STATIC DUMMY for this phase).
///
/// Per the handoff doc: "Riwayat pembelian di detail tetap dummy/statis
/// untuk fase ini". Real history will later come from the transactions
/// table — this shape only exists so the approved UI can be built and
/// reviewed. It is intentionally NOT linked to `features/pos/domain/
/// transaction.dart` yet (nothing is ported/merged in this phase).
class PelangganRiwayat {
  final String date;
  final int total;
  final String items;
  final List<String> tags;

  const PelangganRiwayat({
    required this.date,
    required this.total,
    required this.items,
    required this.tags,
  });
}

/// Last purchase summary shown as the one-line row on the list card.
class PelangganLastPurchase {
  final String text;
  final String time;
  final String date;
  final int total;

  const PelangganLastPurchase({
    required this.text,
    required this.time,
    required this.date,
    required this.total,
  });
}

/// Customer as displayed by the Pelanggan screens.
///
/// STATIC PLACEHOLDER model — deliberately separate from
/// `features/pos/domain/customer.dart` (the POS cart's customer picker).
/// Nothing here touches the POS feature, the database, or the sync queue
/// yet; merging the two is a later step (explicitly out of scope now).
///
/// Business rules kept from AGENTS.md `## Customer`: name required, phone
/// optional, multiple phones allowed, no primary phone (all equal — the
/// list simply shows the first one), phones displayed grouped by four.
class Pelanggan {
  final int id;
  final String name;
  final List<String> phones;
  final String address;
  final PelangganLastPurchase? lastPurchase;

  /// All-time revenue in whole Rupiah (money stays integer per the
  /// architecture doc). Canceled transactions are excluded from omzet.
  final int omzet;
  final int trxCount;

  /// Days since the last order, null when the customer never ordered.
  final int? lastOrderDaysAgo;
  final List<PelangganRiwayat> history;

  const Pelanggan({
    required this.id,
    required this.name,
    required this.phones,
    required this.address,
    required this.lastPurchase,
    required this.omzet,
    required this.trxCount,
    required this.lastOrderDaysAgo,
    required this.history,
  });

  Pelanggan copyWith({
    String? name,
    List<String>? phones,
    String? address,
  }) {
    return Pelanggan(
      id: id,
      name: name ?? this.name,
      phones: phones ?? this.phones,
      address: address ?? this.address,
      lastPurchase: lastPurchase,
      omzet: omzet,
      trxCount: trxCount,
      lastOrderDaysAgo: lastOrderDaysAgo,
      history: history,
    );
  }
}

/// The two list tabs: "Loyal" (top-5 by all-time omzet) and "Semua"
/// (everyone, A-Z).
enum PelangganSort { loyal, semua }

/// Period chips on the detail page. Static toggle only in this phase —
/// dummy data is not actually filtered (same as the approved mockup).
enum PelangganPeriod { hariIni, bulanIni, semuaWaktu }

extension PelangganPeriodLabel on PelangganPeriod {
  String get label => switch (this) {
        PelangganPeriod.hariIni => 'Hari Ini',
        PelangganPeriod.bulanIni => 'Bulan Ini',
        PelangganPeriod.semuaWaktu => 'Semua Waktu',
      };
}

/// A phone number that is already owned by another customer.
class PhoneClash {
  final String phone;
  final Pelanggan owner;
  const PhoneClash(this.phone, this.owner);
}
