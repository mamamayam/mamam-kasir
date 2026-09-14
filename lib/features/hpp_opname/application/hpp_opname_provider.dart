import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hpp_opname_models.dart';
import 'hpp_opname_repository.dart';

final hppOpnameRepositoryProvider = Provider<HppOpnameRepository>((ref) => HppOpnameRepository());

/// One in-progress line in the Stok Opname input form — qty/price start
/// null/unset until the user types something, so "not yet counted" is
/// distinguishable from "counted as zero".
class OpnameDraftLine {
  final double? qty;
  final int priceUsed;
  final bool priceEdited;

  const OpnameDraftLine({this.qty, required this.priceUsed, this.priceEdited = false});

  OpnameDraftLine copyWith({double? qty, int? priceUsed, bool? priceEdited}) {
    return OpnameDraftLine(
      qty: qty ?? this.qty,
      priceUsed: priceUsed ?? this.priceUsed,
      priceEdited: priceEdited ?? this.priceEdited,
    );
  }
}

/// Combined state for the HPP & Stok Opname screen. Both features share
/// one controller because they share one ingredient list and one screen
/// (switchable via the header dropdown, per the mockup) — splitting them
/// into two controllers would mean duplicating the ingredients load.
class HppOpnameState {
  final List<Ingredient> ingredients;
  final IngredientCategory hppCategory;
  final String hppSearchQuery;

  final List<StockOpnameSession> sessions;
  final IngredientCategory opnameCategory;
  final String opnameSearchQuery;
  // Keyed by ingredient id so switching categories mid-session (per
  // Agung's direction) never loses what was already typed elsewhere.
  final Map<String, OpnameDraftLine> opnameDraft;

  final bool isLoading;
  final String? errorMessage;

  const HppOpnameState({
    this.ingredients = const [],
    this.hppCategory = IngredientCategory.baku,
    this.hppSearchQuery = '',
    this.sessions = const [],
    this.opnameCategory = IngredientCategory.baku,
    this.opnameSearchQuery = '',
    this.opnameDraft = const {},
    this.isLoading = true,
    this.errorMessage,
  });

  HppOpnameState copyWith({
    List<Ingredient>? ingredients,
    IngredientCategory? hppCategory,
    String? hppSearchQuery,
    List<StockOpnameSession>? sessions,
    IngredientCategory? opnameCategory,
    String? opnameSearchQuery,
    Map<String, OpnameDraftLine>? opnameDraft,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HppOpnameState(
      ingredients: ingredients ?? this.ingredients,
      hppCategory: hppCategory ?? this.hppCategory,
      hppSearchQuery: hppSearchQuery ?? this.hppSearchQuery,
      sessions: sessions ?? this.sessions,
      opnameCategory: opnameCategory ?? this.opnameCategory,
      opnameSearchQuery: opnameSearchQuery ?? this.opnameSearchQuery,
      opnameDraft: opnameDraft ?? this.opnameDraft,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  List<Ingredient> get hppFilteredIngredients {
    final query = hppSearchQuery.toLowerCase();
    return ingredients
        .where((i) => i.category == hppCategory && i.isActive && i.name.toLowerCase().contains(query))
        .toList();
  }

  List<Ingredient> get opnameFilteredIngredients {
    final query = opnameSearchQuery.toLowerCase();
    return ingredients
        .where((i) => i.category == opnameCategory && i.isActive && i.name.toLowerCase().contains(query))
        .toList();
  }

  /// Total value for whichever category is currently shown in the Input
  /// Baru form — matches the mockup's per-category running total, not a
  /// grand total across every category in the draft.
  int get opnameCategoryTotal {
    var total = 0;
    for (final ingredient in opnameFilteredIngredients) {
      final line = opnameDraft[ingredient.id];
      if (line?.qty != null) total += (line!.qty! * line.priceUsed).round();
    }
    return total;
  }
}

final hppOpnameProvider = StateNotifierProvider.autoDispose<HppOpnameController, HppOpnameState>((ref) {
  return HppOpnameController(ref.watch(hppOpnameRepositoryProvider));
});

class HppOpnameController extends StateNotifier<HppOpnameState> {
  final HppOpnameRepository _repository;

  HppOpnameController(this._repository) : super(const HppOpnameState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ingredients = await _repository.getIngredients();
      final sessions = await _repository.getSessions();
      state = state.copyWith(ingredients: ingredients, sessions: sessions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data: $e');
    }
  }

  // --- HPP ---

  void setHppCategory(IngredientCategory category) => state = state.copyWith(hppCategory: category);

  void setHppSearchQuery(String query) => state = state.copyWith(hppSearchQuery: query);

  Future<void> addIngredient({
    required IngredientCategory category,
    required String name,
    required String unit,
    required int lastPrice,
  }) async {
    try {
      await _repository.createIngredient(category: category, name: name, unit: unit, lastPrice: lastPrice);
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menambah bahan: $e');
    }
  }

  Future<void> updateIngredientPrice(String id, int newPrice) async {
    try {
      await _repository.updateIngredientPrice(id, newPrice);
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memperbarui harga: $e');
    }
  }

  // --- Stok Opname ---

  void setOpnameCategory(IngredientCategory category) => state = state.copyWith(opnameCategory: category);

  void setOpnameSearchQuery(String query) => state = state.copyWith(opnameSearchQuery: query);

  void setDraftQty(String ingredientId, double? qty) {
    final ingredient = state.ingredients.firstWhere((i) => i.id == ingredientId);
    final current = state.opnameDraft[ingredientId];
    final updated = Map<String, OpnameDraftLine>.from(state.opnameDraft);
    // Built directly (not via copyWith) so a cleared field can actually
    // set qty back to null — copyWith's `qty ?? this.qty` pattern can't
    // distinguish "clear this" from "leave it alone".
    updated[ingredientId] = OpnameDraftLine(
      qty: qty,
      priceUsed: current?.priceUsed ?? ingredient.lastPrice,
      priceEdited: current?.priceEdited ?? false,
    );
    state = state.copyWith(opnameDraft: updated);
  }

  void setDraftPrice(String ingredientId, int price) {
    final current = state.opnameDraft[ingredientId];
    final updated = Map<String, OpnameDraftLine>.from(state.opnameDraft);
    updated[ingredientId] = (current ?? const OpnameDraftLine(priceUsed: 0)).copyWith(
      priceUsed: price,
      priceEdited: true,
    );
    state = state.copyWith(opnameDraft: updated);
  }

  /// Submits everything counted across the whole draft (every category
  /// touched this session, not just the one currently shown) — matches
  /// Agung's direction that one session covers all three categories.
  Future<void> submitSession({required bool asDraft}) async {
    final items = state.opnameDraft.entries
        .where((e) => e.value.qty != null)
        .map((e) => StockOpnameItem(ingredientId: e.key, qty: e.value.qty!, priceUsed: e.value.priceUsed))
        .toList();

    if (items.isEmpty) {
      state = state.copyWith(errorMessage: 'Isi minimal satu bahan sebelum menyimpan.');
      return;
    }

    try {
      await _repository.submitSession(items: items, asDraft: asDraft);
      state = state.copyWith(opnameDraft: {});
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menyimpan sesi opname: $e');
    }
  }
}
