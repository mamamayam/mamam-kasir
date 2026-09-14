/// Domain models for HPP (cost-basis ingredient pricing) and Stok Opname
/// (monthly physical stock count), ported from the approved HTML mockup.
/// Both features share the same three-category ingredient list — see
/// [IngredientCategory] — per Agung's direction that Stok Opname's item
/// list "follows" HPP's.
enum IngredientCategory {
  baku('baku', 'Bahan Baku'),
  setengahJadi('setengah_jadi', 'Setengah Jadi'),
  jadi('jadi', 'Bahan Jadi');

  final String dbValue;
  final String label;
  const IngredientCategory(this.dbValue, this.label);

  static IngredientCategory fromDb(String value) {
    return IngredientCategory.values.firstWhere(
      (c) => c.dbValue == value,
      orElse: () => IngredientCategory.baku,
    );
  }
}

/// One row in the HPP ingredient list. `lastPrice` is what HPP shows and
/// edits, and what a new Stok Opname session auto-fills per item.
class Ingredient {
  final String id;
  final IngredientCategory category;
  final String name;
  final String unit;
  final int lastPrice;
  final bool isActive;

  const Ingredient({
    required this.id,
    required this.category,
    required this.name,
    required this.unit,
    required this.lastPrice,
    required this.isActive,
  });

  factory Ingredient.fromMap(Map<String, Object?> map) {
    return Ingredient(
      id: map['id'] as String,
      category: IngredientCategory.fromDb(map['category'] as String),
      name: map['name'] as String,
      unit: map['unit'] as String,
      lastPrice: map['last_price'] as int,
      isActive: (map['is_active'] as int) == 1,
    );
  }
}

enum StockOpnameStatus {
  draft('draft', 'Draft'),
  selesai('selesai', 'Selesai');

  final String dbValue;
  final String label;
  const StockOpnameStatus(this.dbValue, this.label);

  static StockOpnameStatus fromDb(String value) {
    return StockOpnameStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => StockOpnameStatus.draft,
    );
  }
}

/// One completed/in-progress opname pass — can cover items across all
/// three categories in a single session (per Agung's direction: one
/// session, free to switch categories, single submit).
class StockOpnameSession {
  final String id;
  final StockOpnameStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int itemCount;
  final int totalValue;

  const StockOpnameSession({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.completedAt,
    required this.itemCount,
    required this.totalValue,
  });
}

/// One line inside a session: the physical qty counted for an
/// ingredient, and the price used for that count (captured at submit
/// time — see stock_opname_items.price_used in the schema — so editing
/// an ingredient's HPP later never rewrites a past session's value).
class StockOpnameItem {
  final String ingredientId;
  final double qty;
  final int priceUsed;

  const StockOpnameItem({required this.ingredientId, required this.qty, required this.priceUsed});
}
