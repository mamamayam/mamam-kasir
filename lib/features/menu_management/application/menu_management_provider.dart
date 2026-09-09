import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/menu_management_models.dart';

class MenuManagementState {
  final MenuManagementTab tab;
  final String searchQuery;
  final MenuViewMode viewMode;
  final List<MenuItem> menuItems;
  final List<VariantGroup> variantGroups;

  const MenuManagementState({
    required this.tab,
    required this.searchQuery,
    required this.viewMode,
    required this.menuItems,
    required this.variantGroups,
  });

  MenuManagementState copyWith({
    MenuManagementTab? tab,
    String? searchQuery,
    MenuViewMode? viewMode,
  }) {
    return MenuManagementState(
      tab: tab ?? this.tab,
      searchQuery: searchQuery ?? this.searchQuery,
      viewMode: viewMode ?? this.viewMode,
      menuItems: menuItems,
      variantGroups: variantGroups,
    );
  }

  /// Menu items matching the current search query, grouped by category —
  /// preserves first-seen category order, matching the mockup's behavior.
  Map<String, List<MenuItem>> get groupedFilteredMenuItems {
    final query = searchQuery.toLowerCase();
    final filtered = menuItems.where((item) => item.name.toLowerCase().contains(query));
    final grouped = <String, List<MenuItem>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  List<VariantGroup> get filteredVariantGroups {
    final query = searchQuery.toLowerCase();
    return variantGroups.where((group) {
      return group.name.toLowerCase().contains(query) ||
          group.options.any((opt) => opt.toLowerCase().contains(query));
    }).toList();
  }
}

final menuManagementProvider =
    StateNotifierProvider.autoDispose<MenuManagementController, MenuManagementState>(
  (ref) => MenuManagementController(),
);

class MenuManagementController extends StateNotifier<MenuManagementState> {
  MenuManagementController()
      : super(
          MenuManagementState(
            tab: MenuManagementTab.menu,
            searchQuery: '',
            viewMode: MenuViewMode.list,
            menuItems: _demoMenuItems(),
            variantGroups: _demoVariantGroups(),
          ),
        );

  void setTab(MenuManagementTab tab) => state = state.copyWith(tab: tab);

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void clearSearch() => state = state.copyWith(searchQuery: '');

  void cycleViewMode() => state = state.copyWith(viewMode: state.viewMode.next);
}

// Demo data mirrors the supplied React mockup's initial state exactly, so
// the shell renders comparably before real menu data/sync is wired up.
List<MenuItem> _demoMenuItems() => const [
      MenuItem(id: '1', name: 'Brownbutter', price: 18000, unit: 'pcs', stockLabel: 'Tidak Terbatas', category: 'Saus & Bumbu'),
      MenuItem(id: '2', name: 'Firesauce', price: 20000, unit: 'pcs', stockLabel: 'Tidak Terbatas', category: 'Saus & Bumbu'),
      MenuItem(id: '3', name: 'Ayam Crispy Original', price: 15000, unit: 'porsi', stockLabel: 'Tidak Terbatas', category: 'Makanan Utama'),
      MenuItem(id: '4', name: 'Ayam Bakar Madu', price: 17000, unit: 'porsi', stockLabel: 'Tidak Terbatas', category: 'Makanan Utama'),
      MenuItem(id: '5', name: 'Es Teh Manis', price: 5000, unit: 'gelas', stockLabel: 'Tidak Terbatas', category: 'Minuman'),
      MenuItem(id: '6', name: 'Es Jeruk', price: 7000, unit: 'gelas', stockLabel: 'Tidak Terbatas', category: 'Minuman'),
    ];

List<VariantGroup> _demoVariantGroups() => const [
      VariantGroup(id: '1', name: 'Level Pedas', options: ['Level 0', 'Level 1', 'Level 2', 'Level 3']),
      VariantGroup(id: '2', name: 'Pilihan Minuman', options: ['Es Teh Manis', 'Teh Tawar', 'Mineral Water']),
      VariantGroup(id: '3', name: 'Ekstra Topping', options: ['Keju', 'Saus Keju', 'Kremes']),
    ];
