import 'pelanggan_models.dart';

/// Pure business logic for the Pelanggan screens — no Flutter imports, no
/// widgets, so it stays testable and independent of the UI (per the
/// handoff doc: "Business logic ... harus berada di layer domain/service,
/// independen dari widget").
///
/// Behaviour mirrors the approved mockup's JS
/// (`getSortedFilteredCustomers`, `isActiveCustomer`, `saveCustomer`
/// validation) which the handoff calls the approved behaviour spec.
class PelangganLogic {
  PelangganLogic._();

  /// A customer is "aktif" when their last order was within the last 30
  /// days. Never-ordered customers (null) are not active.
  static const int activeWindowDays = 30;

  /// The Loyal tab shows at most this many top customers by omzet.
  static const int loyalLimit = 5;

  static bool isActive(Pelanggan c) {
    final days = c.lastOrderDaysAgo;
    return days != null && days <= activeWindowDays;
  }

  /// Filters by [query] (name OR any phone number, case-insensitive), then
  /// sorts per [sort].
  ///
  /// - [PelangganSort.loyal]: highest all-time omzet first. Capped to the
  ///   top [loyalLimit] ONLY when there is no search query — so a search
  ///   typed while on the Loyal tab still finds customers outside the
  ///   top 5 (search is cross-tab and never capped).
  /// - [PelangganSort.semua]: A-Z by name.
  static List<Pelanggan> sortedFiltered(
    List<Pelanggan> all, {
    required PelangganSort sort,
    required String query,
  }) {
    final q = query.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');

    var list = List<Pelanggan>.from(all);

    if (q.isNotEmpty) {
      list = list.where((c) {
        if (c.name.toLowerCase().contains(q)) return true;
        return c.phones.any((p) {
          if (p.toLowerCase().contains(q)) return true;
          // Also match on digits only, so "08123456" finds "0812 3456 7890"
          // (phones are stored grouped by four but people type them raw).
          return qDigits.isNotEmpty && digitsOnly(p).contains(qDigits);
        });
      }).toList();
    }

    if (sort == PelangganSort.loyal) {
      list.sort((a, b) => b.omzet.compareTo(a.omzet));
      if (q.isEmpty && list.length > loyalLimit) {
        list = list.sublist(0, loyalLimit);
      }
    } else {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return list;
  }

  /// Number of active customers, computed over the WHOLE dataset (never
  /// over a filtered/top-5 slice).
  static int activeCount(List<Pelanggan> all) => all.where(isActive).length;

  /// 1-based loyalty rank of [c] by all-time omzet across ALL customers.
  static int rankOf(List<Pelanggan> all, Pelanggan c) {
    final sorted = List<Pelanggan>.from(all)..sort((a, b) => b.omzet.compareTo(a.omzet));
    return sorted.indexWhere((x) => x.id == c.id) + 1;
  }

  /// Returns the first phone in [phones] that already belongs to a
  /// DIFFERENT customer (one phone = one customer), or null when free.
  /// [editingId] is excluded so a customer never clashes with themself.
  static PhoneClash? findPhoneClash(
    List<Pelanggan> all,
    List<String> phones, {
    int? editingId,
  }) {
    for (final p in phones) {
      final normalized = digitsOnly(p);
      if (normalized.isEmpty) continue;
      for (final c in all) {
        if (c.id == editingId) continue;
        if (c.phones.any((existing) => digitsOnly(existing) == normalized)) {
          return PhoneClash(p, c);
        }
      }
    }
    return null;
  }

  static String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Groups a phone number as typed: max 13 digits, "0812 3456 7890".
  /// Same grouping as the mockup's `formatPhoneInput` (4-4-rest) and the
  /// PRD rule "phone shown starting 08, grouped every four digits".
  static String formatPhone(String input) {
    var digits = digitsOnly(input);
    if (digits.length > 13) digits = digits.substring(0, 13);
    if (digits.length <= 4) return digits;
    final buf = StringBuffer()
      ..write(digits.substring(0, 4))
      ..write(' ')
      ..write(digits.substring(4, digits.length < 8 ? digits.length : 8));
    if (digits.length > 8) {
      buf
        ..write(' ')
        ..write(digits.substring(8));
    }
    return buf.toString();
  }

  /// Rupiah with a space after "Rp" and Indonesian thousand dots
  /// ("Rp 4.850.000"), exactly as the approved mockup renders it.
  ///
  /// Deliberately NOT `core/utils/currency.dart`'s `formatRupiah`, which
  /// renders "Rp4.850.000" (no space) and is used app-wide — changing it
  /// would alter every other screen. This is presentation-only and local
  /// to the Pelanggan feature.
  static String formatRp(int amount) {
    final negative = amount < 0;
    final digits = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${negative ? '-' : ''}Rp $buf';
  }
}
