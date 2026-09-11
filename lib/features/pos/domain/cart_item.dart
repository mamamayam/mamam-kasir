import '../../menu_management/domain/menu_management_models.dart';

/// One line in the cart — a menu item with resolved variant selections.
///
/// `cartItemId` mirrors the reference app's approach: derived from
/// `menuItemId` + sorted selected option ids, so adding the same menu
/// item with the same variant combination again increments qty instead
/// of creating a duplicate line, while a different variant combination
/// becomes its own line.
class CartItem {
  final String cartItemId;
  final String menuItemId;
  final String name;
  final String? variantName; // display string, e.g. "Level 2, Keju"
  final Map<String, List<String>> variantSelectedOptions; // groupId -> optionIds
  final int price; // base price + extra price from selected variants
  final int hpp;
  final int qty;
  final String note;

  const CartItem({
    required this.cartItemId,
    required this.menuItemId,
    required this.name,
    this.variantName,
    this.variantSelectedOptions = const {},
    required this.price,
    required this.hpp,
    required this.qty,
    this.note = '',
  });

  int get lineTotal => price * qty;

  CartItem copyWith({int? qty, String? note}) {
    return CartItem(
      cartItemId: cartItemId,
      menuItemId: menuItemId,
      name: name,
      variantName: variantName,
      variantSelectedOptions: variantSelectedOptions,
      price: price,
      hpp: hpp,
      qty: qty ?? this.qty,
      note: note ?? this.note,
    );
  }
}

/// Builds a [CartItem] from a [MenuItem] and the variant options selected
/// for it, resolving extra price and a display name for the combination —
/// same derivation the reference app's `addToCart` does.
class CartItemBuilder {
  static String buildCartItemId(String menuItemId, Map<String, List<String>> selectedOptions) {
    final optionIds = selectedOptions.values.expand((ids) => ids).toList()..sort();
    return optionIds.isEmpty ? menuItemId : '$menuItemId-${optionIds.join('-')}';
  }

  static CartItem build({
    required MenuItem menu,
    required Map<String, List<String>> selectedOptions,
    required List<VariantGroup> variantGroups,
    required int existingQty,
  }) {
    var extraPriceTotal = 0;
    final variantNames = <String>[];

    for (final entry in selectedOptions.entries) {
      final group = variantGroups.where((g) => g.id == entry.key).firstOrNull;
      if (group == null) continue;
      for (final optionId in entry.value) {
        final option = group.options.where((o) => o.id == optionId).firstOrNull;
        if (option == null) continue;
        extraPriceTotal += option.extraPrice;
        variantNames.add(option.name);
      }
    }

    return CartItem(
      cartItemId: buildCartItemId(menu.id, selectedOptions),
      menuItemId: menu.id,
      name: menu.name,
      variantName: variantNames.isEmpty ? null : variantNames.join(', '),
      variantSelectedOptions: selectedOptions,
      price: menu.price + extraPriceTotal,
      hpp: menu.hpp ?? 0,
      qty: existingQty + 1,
      note: '',
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
