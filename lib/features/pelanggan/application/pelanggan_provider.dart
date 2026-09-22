import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/pelanggan_logic.dart';
import '../domain/pelanggan_models.dart';
import 'pelanggan_dummy_data.dart';

/// State for the Pelanggan placeholder screens (list + detail + form).
///
/// IN-MEMORY ONLY for this phase: seeded from [pelangganDummyData], not
/// persisted to SQLite, not queued for sync, no audit log yet (the
/// handoff requires those for the real implementation — they are the
/// next phases, intentionally not started here per "placeholder dulu").
/// Because the provider is `autoDispose`, edits reset when the user
/// leaves the Pelanggan screens — same as the mockup ("reset saat
/// refresh").
class PelangganState {
  final List<Pelanggan> customers;
  final PelangganSort sort;
  final String searchQuery;
  final PelangganPeriod period;

  const PelangganState({
    this.customers = const [],
    this.sort = PelangganSort.loyal,
    this.searchQuery = '',
    this.period = PelangganPeriod.semuaWaktu,
  });

  PelangganState copyWith({
    List<Pelanggan>? customers,
    PelangganSort? sort,
    String? searchQuery,
    PelangganPeriod? period,
  }) {
    return PelangganState(
      customers: customers ?? this.customers,
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
      period: period ?? this.period,
    );
  }

  bool get isSearching => searchQuery.trim().isNotEmpty;

  /// The rows the list should render right now (search + tab applied).
  List<Pelanggan> get visible =>
      PelangganLogic.sortedFiltered(customers, sort: sort, query: searchQuery);

  /// "Pelanggan aktif X/Y" footer: only on the Loyal tab and only when
  /// not searching; counts computed over ALL customers, not [visible].
  bool get showActiveFooter => sort == PelangganSort.loyal && !isSearching;
  int get activeCount => PelangganLogic.activeCount(customers);
  int get totalCount => customers.length;

  Pelanggan? byId(int id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Outcome of a save attempt — lets the form show the right error
/// without the controller knowing anything about widgets.
sealed class PelangganSaveResult {
  const PelangganSaveResult();
}

class PelangganSaved extends PelangganSaveResult {
  final Pelanggan customer;
  const PelangganSaved(this.customer);
}

class PelangganNameRequired extends PelangganSaveResult {
  const PelangganNameRequired();
}

class PelangganPhoneTaken extends PelangganSaveResult {
  final PhoneClash clash;
  const PelangganPhoneTaken(this.clash);
}

/// The customer being edited no longer exists (e.g. it was deleted while
/// the edit form was still open). Distinct from [PelangganNameRequired]
/// so the form doesn't wrongly tell the user their (filled) name is
/// missing.
class PelangganNotFound extends PelangganSaveResult {
  const PelangganNotFound();
}

class PelangganController extends StateNotifier<PelangganState> {
  PelangganController() : super(const PelangganState(customers: pelangganDummyData));

  int _nextId = pelangganDummyData.length + 1;

  void setSort(PelangganSort sort) => state = state.copyWith(sort: sort);

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void clearSearch() => state = state.copyWith(searchQuery: '');

  void setPeriod(PelangganPeriod period) => state = state.copyWith(period: period);

  /// Detail pages always open on "Semua Waktu" (same as the mockup).
  void resetPeriod() => state = state.copyWith(period: PelangganPeriod.semuaWaktu);

  /// Validates then creates ([editingId] == null) or updates a customer.
  ///
  /// Rules (AGENTS.md `## Customer`): name required; phone optional;
  /// multiple phones; one phone belongs to exactly one customer — a
  /// duplicate is rejected and the EXISTING owner is returned so the UI
  /// can offer that customer instead of a generic error.
  PelangganSaveResult save({
    required int? editingId,
    required String name,
    required List<String> phones,
    required String address,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return const PelangganNameRequired();

    final cleanPhones = phones.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    final clash = PelangganLogic.findPhoneClash(state.customers, cleanPhones, editingId: editingId);
    if (clash != null) return PelangganPhoneTaken(clash);

    if (editingId != null) {
      final existing = state.byId(editingId);
      if (existing == null) return const PelangganNotFound();
      final updated = existing.copyWith(
        name: trimmedName,
        phones: cleanPhones,
        address: address.trim(),
      );
      state = state.copyWith(
        customers: [for (final c in state.customers) if (c.id == editingId) updated else c],
      );
      return PelangganSaved(updated);
    }

    final created = Pelanggan(
      id: _nextId++,
      name: trimmedName,
      phones: cleanPhones,
      address: address.trim(),
      lastPurchase: null,
      omzet: 0,
      trxCount: 0,
      lastOrderDaysAgo: null,
      history: const [],
    );
    state = state.copyWith(customers: [...state.customers, created]);
    return PelangganSaved(created);
  }

  /// Removes the customer from the in-memory list.
  ///
  /// PLACEHOLDER ONLY: the mockup hard-deletes. AGENTS.md says master data
  /// used by history cannot be hard-deleted (use Nonaktif) and the handoff
  /// flags whether customers with transactions may be hard-deleted as an
  /// OPEN QUESTION for the Product Owner — so this is NOT the final
  /// behaviour and must not be carried into the real implementation
  /// without that decision.
  void delete(int id) {
    state = state.copyWith(customers: state.customers.where((c) => c.id != id).toList());
  }
}

final pelangganProvider = StateNotifierProvider.autoDispose<PelangganController, PelangganState>((ref) {
  return PelangganController();
});
