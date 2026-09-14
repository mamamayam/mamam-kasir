import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../menu_management/domain/menu_management_models.dart';

/// Result of [VariantSelectionModal] — selected options plus the chosen
/// quantity (set via the modal's own stepper), so a single confirm tap
/// can add more than one unit at once.
class VariantSelectionResult {
  final Map<String, List<String>> selectedOptions;
  final int quantity;

  const VariantSelectionResult({required this.selectedOptions, required this.quantity});
}

/// Shown as a modal (bottom-up) when a tapped menu item has one or more
/// linked variant groups. Returns a [VariantSelectionResult] via
/// [Navigator.pop], or null if dismissed without completing a required
/// selection.
class VariantSelectionModal extends StatefulWidget {
  final MenuItem menu;
  final List<VariantGroup> allGroups;

  const VariantSelectionModal({super.key, required this.menu, required this.allGroups});

  @override
  State<VariantSelectionModal> createState() => _VariantSelectionModalState();
}

class _VariantSelectionModalState extends State<VariantSelectionModal> {
  final Map<String, List<String>> _selected = {};
  int _quantity = 1;

  List<VariantGroup> get _relevantGroups =>
      widget.allGroups.where((g) => widget.menu.variantGroupIds.contains(g.id) && g.isActive).toList();

  void _toggleOption(VariantGroup group, String optionId) {
    setState(() {
      final current = List<String>.from(_selected[group.id] ?? []);
      if (current.contains(optionId)) {
        current.remove(optionId);
      } else {
        if (group.maxSelection <= 1) {
          current
            ..clear()
            ..add(optionId);
        } else if (current.length < group.maxSelection) {
          current.add(optionId);
        }
      }
      _selected[group.id] = current;
    });
  }

  void _incrementQty() => setState(() => _quantity++);

  void _decrementQty() => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1);

  int get _extraPriceTotal {
    var total = 0;
    for (final group in _relevantGroups) {
      final selectedIds = _selected[group.id] ?? [];
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) total += option.extraPrice;
      }
    }
    return total;
  }

  bool get _canConfirm {
    for (final group in _relevantGroups) {
      if (group.isRequired && (_selected[group.id]?.isEmpty ?? true)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _relevantGroups;
    final unitPrice = widget.menu.price + _extraPriceTotal;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Drag handle, replacing the old close-icon header bar —
                  // this sheet now leads with the product card below
                  // instead, matching the reference design.
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 6),
                    child: Container(
                      width: 56,
                      height: 5,
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 100),
                      children: [
                        _ProductHeaderCard(menu: widget.menu),
                        const SizedBox(height: AppSpacing.xl),
                        ...groups.map((group) => _VariantGroupSection(
                              group: group,
                              selectedIds: _selected[group.id] ?? [],
                              onToggle: (optionId) => _toggleOption(group, optionId),
                            )),
                        const Divider(height: AppSpacing.xxl),
                        _QtySelector(quantity: _quantity, onDecrement: _decrementQty, onIncrement: _incrementQty),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: const Border(top: BorderSide(color: AppColors.border)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                          Text(
                            formatRupiah(unitPrice * _quantity),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _canConfirm
                              ? () => Navigator.of(context).pop(VariantSelectionResult(selectedOptions: _selected, quantity: _quantity))
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.border,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                            elevation: 0,
                          ),
                          child: const Text('Add to Cart', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Product identity card at the top of the sheet — thumbnail, name,
/// price, and a "Stok ∞" badge. The menu model has no image or stock
/// field (this app has no stock-tracking feature at all — see product
/// notes), so the thumbnail is a generic icon placeholder and the stock
/// badge is a fixed decorative "∞", not real data.
class _ProductHeaderCard extends StatelessWidget {
  final MenuItem menu;
  const _ProductHeaderCard({required this.menu});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Icon(Icons.fastfood_rounded, size: 24, color: AppColors.textMuted),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        menu.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(formatRupiah(menu.price), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              SizedBox(height: 2),
              Icon(Icons.all_inclusive_rounded, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _VariantGroupSection extends StatelessWidget {
  final VariantGroup group;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _VariantGroupSection({required this.group, required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isSingleSelect = group.maxSelection <= 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 6),
              if (group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                  child: const Text('WAJIB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.danger)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isSingleSelect ? 'Pilih 1' : 'Pilih maks. ${group.maxSelection}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...group.options.map((option) {
            final selected = selectedIds.contains(option.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: () => onToggle(option.id),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: selected ? AppColors.brand : AppColors.border, width: selected ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        // Kept for multi-select groups so it's still clear
                        // more than one option can be checked; single-select
                        // groups (the common case, e.g. "Level Pedas") omit
                        // it entirely to match the reference design's plain
                        // pill-row look.
                        if (!isSingleSelect) ...[
                          Icon(
                            selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: selected ? AppColors.brand : AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            option.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? AppColors.brand : AppColors.textPrimary),
                          ),
                        ),
                        Text(
                          option.extraPrice > 0 ? '+${formatRupiah(option.extraPrice)}' : 'Free',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? AppColors.brand : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Quantity stepper for the whole line — separate row below the variant
/// groups (per reference design), distinct in style from the smaller
/// per-cart-item stepper in [CartDrawer].
class _QtySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtySelector({required this.quantity, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleStepperButton(icon: Icons.remove_rounded, onTap: quantity > 1 ? onDecrement : null, filled: false),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
        ),
        _CircleStepperButton(icon: Icons.add_rounded, onTap: onIncrement, filled: true),
      ],
    );
  }
}

class _CircleStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  const _CircleStepperButton({required this.icon, required this.onTap, required this.filled});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Material(
      color: filled ? AppColors.textPrimary : AppColors.background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: filled ? Colors.white : (isEnabled ? AppColors.textPrimary : AppColors.textMuted)),
        ),
      ),
    );
  }
}
