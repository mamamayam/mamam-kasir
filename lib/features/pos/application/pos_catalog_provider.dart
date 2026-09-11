import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../menu_management/domain/menu_management_models.dart';
import '../domain/customer.dart';
import 'cart_provider.dart';
import 'pos_repository.dart';

class PosCatalogState {
  final List<MenuItem> menuItems;
  final List<VariantGroup> variantGroups;
  final List<Customer> customers;
  final bool isLoading;
  final String? errorMessage;

  const PosCatalogState({
    this.menuItems = const [],
    this.variantGroups = const [],
    this.customers = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  PosCatalogState copyWith({
    List<MenuItem>? menuItems,
    List<VariantGroup>? variantGroups,
    List<Customer>? customers,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PosCatalogState(
      menuItems: menuItems ?? this.menuItems,
      variantGroups: variantGroups ?? this.variantGroups,
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  List<String> get categoryNames => menuItems.map((m) => m.categoryName).toSet().toList();
}

final posCatalogProvider = StateNotifierProvider.autoDispose<PosCatalogController, PosCatalogState>((ref) {
  return PosCatalogController(ref.watch(posRepositoryProvider));
});

class PosCatalogController extends StateNotifier<PosCatalogState> {
  final PosRepository _repository;

  PosCatalogController(this._repository) : super(const PosCatalogState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final menuItems = await _repository.getActiveMenuItems();
      final variantGroups = await _repository.getVariantGroups();
      final customers = await _repository.getActiveCustomers();
      state = state.copyWith(
        menuItems: menuItems,
        variantGroups: variantGroups,
        customers: customers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data: $e');
    }
  }
}
