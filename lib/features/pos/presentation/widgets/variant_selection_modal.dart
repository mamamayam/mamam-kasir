import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../menu_management/domain/menu_management_models.dart';

/// Shown as a modal (bottom-up) when a tapped menu item has one or more
/// linked variant groups. Returns the selected options map (groupId ->
/// list of optionIds) via [Navigator.pop], or null if dismissed without
/// completing a required selection.
class VariantSelectionModal extends StatefulWidget {
  final MenuItem menu;
  final List<VariantGroup> allGroups;

  const VariantSelectionModal({super.key, required this.menu, required this.allGroups});

  @override
  State<VariantSelectionModal> createState() => _VariantSelectionModalState();
}

class _VariantSelectionModalState extends State<VariantSelectionModal> {
  final Map<String, List<String>> _selected = {};

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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        ),
                        Expanded(
                          child: Text(
                            widget.menu.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 100),
                      children: groups.map((group) => _VariantGroupSection(
                            group: group,
                            selectedIds: _selected[group.id] ?? [],
                            onToggle: (optionId) => _toggleOption(group, optionId),
                          )).toList(),
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canConfirm ? () => Navigator.of(context).pop(_selected) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Tambah • ${formatRupiah(widget.menu.price + _extraPriceTotal)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
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
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: () => onToggle(option.id),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: selected ? AppColors.brand : AppColors.border, width: selected ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? (isSingleSelect ? Icons.radio_button_checked_rounded : Icons.check_box_rounded)
                              : (isSingleSelect ? Icons.radio_button_off_rounded : Icons.check_box_outline_blank_rounded),
                          size: 20,
                          color: selected ? AppColors.brand : AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(option.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                        if (option.extraPrice > 0)
                          Text(
                            '+${formatRupiah(option.extraPrice)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
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
