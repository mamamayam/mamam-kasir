import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../menu_management/domain/menu_management_models.dart';
import '../application/cart_provider.dart';
import '../application/pos_catalog_provider.dart';
import 'widgets/cart_drawer.dart';
import 'widgets/variant_selection_modal.dart';

/// Kasir (POS) screen. Reached via [AppNav.push] from the dashboard's
/// "Kasir" quick action — a "going deeper" destination per the app's
/// stack-navigation model.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory; // null = "Semua"

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final cartCount = cartState.cart.fold<int>(0, (sum, item) => sum + item.qty);

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
                const _Header(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cari menu...',
                      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                ),
                if (!catalog.isLoading)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      children: [
                        _CategoryChip(label: 'Semua', selected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null)),
                        const SizedBox(width: AppSpacing.sm),
                        ...catalog.categoryNames.map((cat) => Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: _CategoryChip(label: cat, selected: _selectedCategory == cat, onTap: () => setState(() => _selectedCategory = cat)),
                            )),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: catalog.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                      : filteredItems.isEmpty
                          ? const Center(child: Text('Menu tidak ditemukan.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)))
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 110),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppSpacing.md,
                                crossAxisSpacing: AppSpacing.md,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _MenuGridCard(item: item, onTap: () => _handleMenuTap(item, catalog));
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      decoration: const BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            ),
          ),
          const Text('Kasir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MenuGridCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const _MenuGridCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Icon(Icons.restaurant_rounded, size: 28, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2),
              ),
              const SizedBox(height: 4),
              Text(formatRupiah(item.price), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand)),
            ],
          ),
        ),
      ),
    );
  }
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
