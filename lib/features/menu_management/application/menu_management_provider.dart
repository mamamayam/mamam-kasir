import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/menu_management_models.dart';
import 'menu_management_repository.dart';

final menuManagementRepositoryProvider = Provider<MenuManagementRepository>((ref) {
  return MenuManagementRepository();
});

class MenuManagementState {
  final MenuManagementTab tab;
  final String searchQuery;
  final MenuViewMode viewMode;
  final List<MenuItem> menuItems;
  final List<VariantGroup> variantGroups;
  final bool isLoading;
  final String? errorMessage;

  const MenuManagementState({
    required this.tab,
    required this.searchQuery,
    required this.viewMode,
    required this.menuItems,
    required this.variantGroups,
    required this.isLoading,
    this.errorMessage,
  });

  factory MenuManagementState.initial() => const MenuManagementState(
        tab: MenuManagementTab.menu,
        searchQuery: '',
        viewMode: MenuViewMode.list,
        menuItems: [],
        variantGroups: [],
        isLoading: true,
      );

  MenuManagementState copyWith({
    MenuManagementTab? tab,
    String? searchQuery,
    MenuViewMode? viewMode,
    List<MenuItem>? menuItems,
    List<VariantGroup>? variantGroups,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MenuManagementState(
      tab: tab ?? this.tab,
      searchQuery: searchQuery ?? this.searchQuery,
      viewMode: viewMode ?? this.viewMode,
      menuItems: menuItems ?? this.menuItems,
      variantGroups: variantGroups ?? this.variantGroups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Menu items matching the current search query, grouped by category —
  /// preserves first-seen category order, matching the mockup's behavior.
  /// Inactive items are included here (visually dimmed by the card, see
  /// [MenuItemCard]) rather than hidden — hiding them silently would make
  /// "where did my item go" a support question once real deactivation is
  /// used; a future filter toggle can hide them explicitly if wanted.
  Map<String, List<MenuItem>> get groupedFilteredMenuItems {
    final query = searchQuery.toLowerCase();
    final filtered = menuItems.where((item) => item.name.toLowerCase().contains(query));
    final grouped = <String, List<MenuItem>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.categoryName, () => []).add(item);
    }
    return grouped;
  }

  List<VariantGroup> get filteredVariantGroups {
    final query = searchQuery.toLowerCase();
    return variantGroups.where((group) {
      return group.name.toLowerCase().contains(query) ||
          group.options.any((opt) => opt.name.toLowerCase().contains(query));
    }).toList();
  }
}

final menuManagementProvider =
    StateNotifierProvider.autoDispose<MenuManagementController, MenuManagementState>(
  (ref) => MenuManagementController(ref.watch(menuManagementRepositoryProvider)),
);

class MenuManagementController extends StateNotifier<MenuManagementState> {
  final MenuManagementRepository _repository;

  MenuManagementController(this._repository) : super(MenuManagementState.initial()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repository.getMenuItems();
      final groups = await _repository.getVariantGroups();
      state = state.copyWith(menuItems: items, variantGroups: groups, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data: $e');
    }
  }

  void setTab(MenuManagementTab tab) => state = state.copyWith(tab: tab);

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void clearSearch() => state = state.copyWith(searchQuery: '');

  void cycleViewMode() => state = state.copyWith(viewMode: state.viewMode.next);

  Future<void> createMenuItem({
    required String categoryName,
    required String name,
    required int price,
    int? hpp,
    required String unit,
    List<String> variantGroupIds = const [],
  }) async {
    try {
      await _repository.createMenuItem(
        categoryName: categoryName,
        name: name,
        price: price,
        hpp: hpp,
        unit: unit,
        variantGroupIds: variantGroupIds,
      );
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menyimpan menu: $e');
    }
  }

  Future<void> updateMenuItem(MenuItem item) async {
    try {
      await _repository.updateMenuItem(item);
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memperbarui menu: $e');
    }
  }

  Future<void> deactivateMenuItem(String id) async {
    try {
      await _repository.deactivateMenuItem(id);
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menonaktifkan menu: $e');
    }
  }

  Future<void> reactivateMenuItem(String id) async {
    try {
      await _repository.reactivateMenuItem(id);
      await loadAll();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal mengaktifkan menu: $e');
    }
  }
}
