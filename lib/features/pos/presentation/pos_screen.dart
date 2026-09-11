import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../../menu_management/domain/menu_management_models.dart';
import '../application/cart_provider.dart';
import '../application/kasir_grid_pref_provider.dart';
import '../application/pos_catalog_provider.dart';
import 'widgets/cart_drawer.dart';
import 'widgets/category_filter_sheet.dart';
import 'widgets/variant_selection_modal.dart';

/// Kasir (POS) screen. Reached via [AppNav.push] from the dashboard's
/// "Kasir" quick action -- a "going deeper" destination per the app's
/// stack-navigation model.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedCategory; // null = "Semua"
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    // Wait for the expand animation to be underway before requesting
    // focus, so the keyboard doesn't jump the layout mid-animation.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _openCategoryFilter(List<String> categoryNames) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CategoryFilterSheet(categories: categoryNames, selectedCategory: _selectedCategory),
    );
    // The sheet only pops a value from an explicit row tap ("Semua" pops
    // null, a named category pops its name); dismissing without tapping
    // a row also resolves to null here, which is indistinguishable from
    // explicitly choosing "Semua" -- acceptable since both leave the grid
    // unfiltered.
    if (!mounted) return;
    setState(() => _selectedCategory = result);
  }

  Future<void> _handleMenuTap(MenuItem menu, PosCatalogState catalog) async {
    final cartController = ref.read(cartProvider.notifier);

    if (menu.variantGroupIds.isEmpty) {
      cartController.addToCart(menu, const {}, catalog.variantGroups);
      return;
    }

    final selected = await showModalBottomSheet<VariantSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VariantSelectionModal(menu: menu, allGroups: catalog.variantGroups),
    );

    if (selected != null) {
      cartController.addToCart(menu, selected.selectedOptions, catalog.variantGroups, quantity: selected.quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(posCatalogProvider);
    final cartState = ref.watch(cartProvider);
    final gridColumns = ref.watch(kasirGridColumnsProvider);
    final cartCount = cartState.cart.fold<int>(0, (sum, item) => sum + item.qty);

    // Quantity currently in the cart per menu item id, summed across any
    // variant-distinct cart lines -- drives the dark badge on each card.
    final qtyByMenuId = <String, int>{};
    for (final line in cartState.cart) {
      qtyByMenuId[line.menuItemId] = (qtyByMenuId[line.menuItemId] ?? 0) + line.qty;
    }

    final filteredItems = catalog.menuItems.where((item) {
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || item.categoryName == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const IosPageHeader(title: Text('Kasir')),
                _KasirToolbar(
                  isSearching: _isSearching,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onSearchChanged: (v) => setState(() => _searchQuery = v),
                  onOpenSearch: _openSearch,
                  onCloseSearch: _closeSearch,
                  isFilterActive: _selectedCategory != null,
                  onFilterTap: catalog.isLoading ? null : () => _openCategoryFilter(catalog.categoryNames),
                  gridColumns: gridColumns,
                  onGridToggle: () => ref.read(kasirGridColumnsProvider.notifier).toggle(),
                ),
                Expanded(
                  child: catalog.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                      : filteredItems.isEmpty
                          ? const Center(child: Text('Menu tidak ditemukan.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)))
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 110),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridColumns,
                                mainAxisSpacing: gridColumns == 3 ? AppSpacing.sm : AppSpacing.md,
                                crossAxisSpacing: gridColumns == 3 ? AppSpacing.sm : AppSpacing.md,
                                childAspectRatio: gridColumns == 3 ? 0.72 : 0.85,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _MenuGridCard(
                                  item: item,
                                  qtyInCart: qtyByMenuId[item.id] ?? 0,
                                  compact: gridColumns == 3,
                                  onTap: () => _handleMenuTap(item, catalog),
                                );
                              },
                            ),
                ),
              ],
            ),
            if (cartCount > 0)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.md,
                child: _CartFab(
                  itemCount: cartCount,
                  total: cartState.cart.fold(0, (sum, item) => sum + item.lineTotal),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CartDrawer(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The row beneath the header: Filter -> Grid toggle -> Search, in that
/// fixed order. Idle state shows all three as equal circular buttons,
/// right-aligned. Tapping search expands it into a full-width bar that
/// grows from the left edge -- Filter and Grid collapse out of the way --
/// with a separate solid dark close button appearing at the right, per
/// the approved reference design.
class _KasirToolbar extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final bool isFilterActive;
  final VoidCallback? onFilterTap;
  final int gridColumns;
  final VoidCallback onGridToggle;

  const _KasirToolbar({
    required this.isSearching,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.isFilterActive,
    required this.onFilterTap,
    required this.gridColumns,
    required this.onGridToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.md),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            // Idle: this filler pushes Filter/Grid/Search into a tight
            // right-aligned cluster. Searching: it collapses to zero so
            // the search bar (now Expanded) can grow from the left edge.
            if (!isSearching) const Spacer(),

            // Filter icon -- collapses to zero width while searching.
            _CollapsibleIcon(
              visible: !isSearching,
              child: _ToolCircleButton(
                onTap: onFilterTap,
                active: isFilterActive,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.tune_rounded, size: 20),
                    if (isFilterActive)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _CollapsibleIcon(visible: !isSearching, child: const SizedBox(width: AppSpacing.sm)),

            // Grid toggle -- collapses to zero width while searching.
            _CollapsibleIcon(
              visible: !isSearching,
              child: _ToolCircleButton(
                onTap: onGridToggle,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    gridColumns == 2 ? Icons.grid_view_rounded : Icons.apps_rounded,
                    key: ValueKey(gridColumns),
                    size: 19,
                  ),
                ),
              ),
            ),
            _CollapsibleIcon(visible: !isSearching, child: const SizedBox(width: AppSpacing.sm)),

            // Search bar. Idle: a fixed 44x44 circle (rightmost of the
            // three icons). Searching: becomes Expanded so it grows to
            // fill the row from the left edge, since Filter/Grid/Spacer
            // have all collapsed away above.
            isSearching
                ? Expanded(
                    child: _SearchBarSurface(
                      isSearching: true,
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      onOpenSearch: onOpenSearch,
                    ),
                  )
                : _SearchBarSurface(
                    isSearching: false,
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onChanged: onSearchChanged,
                    onOpenSearch: onOpenSearch,
                  ),

            // Close button -- a separate solid-dark circle, distinct from
            // the search bar's white surface, appearing only once the
            // bar has expanded.
            _CollapsibleIcon(
              visible: isSearching,
              leftGap: true,
              child: Material(
                color: AppColors.textPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onCloseSearch,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The search control's visual surface. Idle: a plain 44x44 circular
/// button -- same size and shadow as the Filter/Grid buttons beside it --
/// showing only the search glyph. Searching: an expanded rounded bar
/// (same surface color/shadow) containing the search glyph followed by
/// a live [TextField]. Kept as one widget so [AnimatedContainer] can
/// morph smoothly between the two shapes (circle -> pill) instead of
/// swapping between unrelated widgets.
class _SearchBarSurface extends StatelessWidget {
  final bool isSearching;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenSearch;

  const _SearchBarSurface({
    required this.isSearching,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onOpenSearch,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSearching ? null : onOpenSearch,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: isSearching ? null : 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: isSearching ? MainAxisSize.max : MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.search_rounded, size: 19, color: isSearching ? AppColors.textPrimary : AppColors.textMuted),
            ),
            if (isSearching)
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isSearching ? 1 : 0,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Cari produk...',
                      hintStyle: TextStyle(fontSize: 14.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.only(right: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animates a child's width between its natural size and zero, used to
/// slide the filter/grid icons out of the way (or the close button into
/// place) as the search bar expands/collapses.
class _CollapsibleIcon extends StatelessWidget {
  final bool visible;
  final Widget child;
  final bool leftGap;

  const _CollapsibleIcon({required this.visible, required this.child, this.leftGap = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: !visible
          ? const SizedBox(width: 0, height: 44)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leftGap) const SizedBox(width: AppSpacing.sm),
                child,
              ],
            ),
    );
  }
}

class _ToolCircleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool active;
  final Widget child;

  const _ToolCircleButton({required this.onTap, required this.child, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.brand : AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: IconTheme(
            data: IconThemeData(color: active ? Colors.white : AppColors.textPrimary),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Menu grid card. Shows a placeholder thumbnail (four muted geometric
/// shapes, standing in for a future product photo), the item name and
/// price, and -- when the item already has quantity in the cart -- a dark
/// rounded badge with the count, matching the approved reference design.
class _MenuGridCard extends StatelessWidget {
  final MenuItem item;
  final int qtyInCart;
  final bool compact;
  final VoidCallback onTap;

  const _MenuGridCard({required this.item, required this.qtyInCart, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(compact ? AppRadius.md : AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? AppRadius.md : AppRadius.lg),
        child: Container(
          padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? AppRadius.md : AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md),
                      ),
                      child: Center(child: _PlaceholderThumb(compact: compact)),
                    ),
                    if (qtyInCart > 0)
                      Positioned(
                        top: compact ? 5 : 8,
                        right: compact ? 5 : 8,
                        child: Container(
                          constraints: BoxConstraints(minWidth: compact ? 20 : 26, minHeight: compact ? 20 : 26),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(compact ? 10 : 13)),
                          child: Center(
                            child: Text(
                              '$qtyInCart',
                              style: TextStyle(fontSize: compact ? 10 : 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: compact ? 11 : 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: formatRupiah(item.price),
                      style: TextStyle(fontSize: compact ? 10.5 : 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    TextSpan(
                      text: ' / ${item.unit}',
                      style: TextStyle(fontSize: compact ? 9.5 : 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four muted geometric shapes (triangle, heart, circle, square) standing
/// in for a product photo -- matches the reference design's icon-grid
/// placeholder look until real menu photos exist.
class _PlaceholderThumb extends StatelessWidget {
  final bool compact;
  const _PlaceholderThumb({required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 8.0 : 11.0;
    final gap = compact ? 3.0 : 4.0;
    Widget shape(Widget child) => SizedBox(width: size, height: size, child: child);
    const color = Color(0xFFC9CFDA);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            shape(CustomPaint(painter: _TrianglePainter(color: color))),
            SizedBox(width: gap),
            shape(const Icon(Icons.favorite_rounded, color: color, size: 999)),
          ],
        ),
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            shape(const DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
            SizedBox(width: gap),
            shape(DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))),
          ],
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => oldDelegate.color != color;
}

class _CartFab extends StatelessWidget {
  final int itemCount;
  final int total;
  final VoidCallback onTap;
  const _CartFab({required this.itemCount, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text('$itemCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text('Lihat Keranjang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              const Spacer(),
              Text(formatRupiah(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}