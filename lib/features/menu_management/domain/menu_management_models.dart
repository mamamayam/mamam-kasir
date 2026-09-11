/// A menu category (e.g. "Makanan Utama").
class MenuCategory {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });
}

/// A sellable menu item (e.g. "Ayam Crispy Original").
///
/// `categoryId` + `categoryName` both live here rather than just an id:
/// the UI groups by category name directly (see
/// [MenuManagementState.groupedFilteredMenuItems]), and carrying the
/// resolved name avoids every screen needing a separate category lookup
/// just to render a section header.
class MenuItem {
  final String id;
  final String categoryId;
  final String categoryName;
  final String name;
  final int price;
  final int? hpp;
  final String unit; // e.g. "porsi", "pcs", "gelas"
  final bool isActive;
  final List<String> variantGroupIds;

  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.price,
    this.hpp,
    required this.unit,
    required this.isActive,
    this.variantGroupIds = const [],
  });

  /// Per edge-case rule ("Inactive masters cannot be newly selected;
  /// history remains snapshot-based") — inactive items are never
  /// hard-deleted, just flagged. This flag is what future
  /// selection/search UIs should filter on once transactions exist.
  MenuItem copyWith({
    String? categoryId,
    String? categoryName,
    String? name,
    int? price,
    int? hpp,
    String? unit,
    bool? isActive,
    List<String>? variantGroupIds,
  }) {
    return MenuItem(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      price: price ?? this.price,
      hpp: hpp ?? this.hpp,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      variantGroupIds: variantGroupIds ?? this.variantGroupIds,
    );
  }
}

/// A single selectable option within a variant group (e.g. "Level 2",
/// or "Keju" with an extra price).
class VariantOption {
  final String id;
  final String name;
  final int extraPrice;

  const VariantOption({
    required this.id,
    required this.name,
    required this.extraPrice,
  });
}

/// A variant group (e.g. "Level Pedas" -> Level 0/1/2/3).
///
/// `isRequired` and `maxSelection` mirror the reference app's variant
/// selection rules: a required group must have at least one option
/// picked before the item can be added to cart; `maxSelection` caps how
/// many options can be picked at once (1 = single-select/radio-like,
/// >1 = multi-select up to that count).
class VariantGroup {
  final String id;
  final String name;
  final bool isRequired;
  final int maxSelection;
  final bool isActive;
  final List<VariantOption> options;

  const VariantGroup({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.maxSelection,
    required this.isActive,
    required this.options,
  });
}

/// Which tab is active in the Menu Management screen's title dropdown.
enum MenuManagementTab { menu, varian }

/// How items are laid out in the scrollable list.
enum MenuViewMode { list, grid2, grid3 }

extension MenuViewModeX on MenuViewMode {
  MenuViewMode get next {
    switch (this) {
      case MenuViewMode.list:
        return MenuViewMode.grid2;
      case MenuViewMode.grid2:
        return MenuViewMode.grid3;
      case MenuViewMode.grid3:
        return MenuViewMode.list;
    }
  }
}
