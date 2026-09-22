import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shared chrome (header, search pill, two-option pill tab, chips) for the
/// Pelanggan screens.
///
/// WHY these are local instead of reusing `IosPageHeader` /
/// `SlidingPillTabs` / `AppTextField.search` / `DateFilterTabs`:
/// the request was "tampilannya sama persis kaya file preview html".
/// The shared widgets differ from the approved mockup in measurable ways
/// (e.g. the shared pill tab uses 4px padding / 13px font / textSecondary
/// idle text; the mockup uses 5px padding / 14.5px font / textPrimary idle
/// text; the shared search is a `background`-filled bar inside a card,
/// the mockup's is a white pill on the page background). Matching the
/// mockup exactly therefore needs these local variants. If the product
/// owner later prefers the shared look, swapping is a small, isolated
/// change confined to this file.

// ---- Sizes taken 1:1 from the mockup CSS (px == logical pixels). ----
const double _kCircleBtn = 44;
const double _kHeaderHeight = 60;

/// Header: circular back button (left), centered 21/w800 title, optional
/// circular action button (right). Mockup `.header` / `.circle-btn`.
class PelangganHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final VoidCallback onLeadingTap;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final Color? trailingIconColor;

  const PelangganHeader({
    super.key,
    required this.title,
    required this.onLeadingTap,
    this.leadingIcon = Icons.chevron_left_rounded,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailingIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // margin-top:10px in the mockup.
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: _kHeaderHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pelangganTextPrimary,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: PelangganCircleButton(icon: leadingIcon, onTap: onLeadingTap),
              ),
              if (trailingIcon != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: PelangganCircleButton(
                    icon: trailingIcon!,
                    onTap: onTrailingTap,
                    iconColor: trailingIconColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44x44 white circle, 24px icon. Mockup `.circle-btn` (no shadow there).
class PelangganCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  const PelangganCircleButton({super.key, required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: _kCircleBtn,
          height: _kCircleBtn,
          child: Icon(icon, size: 24, color: iconColor ?? AppColors.pelangganTextPrimary),
        ),
      ),
    );
  }
}

/// White pill search field with a clear (x) button that appears only when
/// there is text. Mockup `.search-pill`: margin 8/16/16/16, padding
/// 14/18, 15px text, 10px gap.
class PelangganSearchPill extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  const PelangganSearchPill({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText = 'Cari nama atau no. HP...',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: AppColors.pelangganTextMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 15, color: AppColors.pelangganTextPrimary),
                cursorColor: AppColors.pelangganTextPrimary,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: const TextStyle(fontSize: 15, color: AppColors.pelangganTextMuted),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: AppColors.pelangganBorder, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 12, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-option sliding pill tab. Mockup `.pill-tab`: white pill, 5px inner
/// padding, dark thumb that glides (260ms, cubic-bezier(0.4,0,0.2,1)),
/// buttons 13px vertical padding, 14.5px w700, idle text textPrimary,
/// active text white.
class PelangganPillTab extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PelangganPillTab({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double _pad = 5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // margin: 8px top (inline style) / 16px sides / 12px bottom.
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segment = constraints.maxWidth / labels.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: const Cubic(0.4, 0, 0.2, 1),
                  left: segment * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: segment,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.pelangganTextPrimary,
                      borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(labels.length, (i) {
                    final selected = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onSelected(i),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 260),
                            curve: const Cubic(0.4, 0, 0.2, 1),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppColors.pelangganTextPrimary,
                            ),
                            child: Text(labels[i], textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Horizontal chip row (period filter). Mockup `.chip-row` / `.chip`:
/// padding 9/16, 13px w700, gap 8, active = dark fill + white text, idle =
/// white fill + textSecondary. Not scroll-clipped when it fits.
class PelangganChipRow<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const PelangganChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _Chip(
              label: labelBuilder(options[i]),
              active: options[i] == selected,
              onTap: () => onSelected(options[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.pelangganTextPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
