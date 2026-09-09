/// A sellable menu item (e.g. "Ayam Crispy Original").
class MenuItem {
  final String id;
  final String name;
  final int price;
  final String unit; // e.g. "porsi", "pcs", "gelas"
  final String stockLabel; // e.g. "Tidak Terbatas" — display-only for shell phase
  final String category;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    required this.stockLabel,
    required this.category,
  });
}

/// A variant group (e.g. "Level Pedas" -> ["Level 0", "Level 1", ...]).
class VariantGroup {
  final String id;
  final String name;
  final List<String> options;

  const VariantGroup({
    required this.id,
    required this.name,
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
