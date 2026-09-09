import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/menu_management_provider.dart';
import '../domain/menu_management_models.dart';
import 'widgets/add_menu_item_modal.dart';
import 'widgets/menu_item_card.dart';
import 'widgets/menu_management_header.dart';
import 'widgets/variant_group_card.dart';

/// Menu / Varian management screen.
///
/// This is the reference-pattern screen for all future feature screens
/// (per instruction): header with back + dropdown title + add button,
/// search + view-mode toggle, category-grouped content that adapts across
/// list/grid2/grid3, and a swipe-up add-form modal.
///
/// Reached via [AppNav.push] (slide in from the right) from the dashboard's
/// swipe-up menu — a "going deeper" destination, not a temporary action.
class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuManagementProvider);
    final controller = ref.read(menuManagementProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            MenuManagementHeader(
              currentTab: state.tab,
              onTabSelected: controller.setTab,
              onBack: () => Navigator.of(context).pop(),
              onAdd: () => AppNav.showModal(context, builder: (_) => const AddMenuItemModal()),
            ),
            _SearchRow(
              controller: _searchController,
              state: state,
              onChanged: controller.setSearchQuery,
              onClear: () {
                _searchController.clear();
                controller.clearSearch();
              },
              onToggleViewMode: controller.cycleViewMode,
            ),
            Expanded(
              child: state.tab == MenuManagementTab.menu
                  ? _MenuTabContent(state: state)
                  : _VarianTabContent(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final MenuManagementState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onToggleViewMode;

  const _SearchRow({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onClear,
    required this.onToggleViewMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari ${state.tab == MenuManagementTab.menu ? 'menu' : 'varian'}...',
                  hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.textMuted),
                  suffixIcon: state.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
                          onPressed: onClear,
                        )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: onToggleViewMode,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(_toggleIcon(state.viewMode), size: 19, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _toggleIcon(MenuViewMode mode) {
    switch (mode) {
      case MenuViewMode.list:
        return Icons.grid_view_rounded;
      case MenuViewMode.grid2:
        return Icons.apps_rounded;
      case MenuViewMode.grid3:
        return Icons.view_list_rounded;
    }
  }
}

class _MenuTabContent extends StatelessWidget {
  final MenuManagementState state;
  const _MenuTabContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final grouped = state.groupedFilteredMenuItems;

    if (grouped.isEmpty) {
      return const _EmptyState(message: 'Menu tidak ditemukan.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: grouped.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 2),
                child: Text(
                  entry.key.toUpperCase(),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5),
                ),
              ),
              _ItemLayout(
                viewMode: state.viewMode,
                children: entry.value.map((item) => MenuItemCard(item: item, viewMode: state.viewMode)).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _VarianTabContent extends StatelessWidget {
  final MenuManagementState state;
  const _VarianTabContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final groups = state.filteredVariantGroups;

    if (groups.isEmpty) {
      return const _EmptyState(message: 'Varian tidak ditemukan.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _ItemLayout(
          viewMode: state.viewMode,
          children: groups.map((g) => VariantGroupCard(group: g, viewMode: state.viewMode)).toList(),
        ),
      ],
    );
  }
}

/// Lays out children as a vertical list (list mode) or a grid (grid2/3).
class _ItemLayout extends StatelessWidget {
  final MenuViewMode viewMode;
  final List<Widget> children;

  const _ItemLayout({required this.viewMode, required this.children});

  @override
  Widget build(BuildContext context) {
    if (viewMode == MenuViewMode.list) {
      return Column(
        children: children
            .map((c) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: c))
            .toList(),
      );
    }

    final crossAxisCount = viewMode == MenuViewMode.grid2 ? 2 : 3;
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: crossAxisCount == 2 ? 0.78 : 0.72,
      children: children,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      ),
    );
  }
}
