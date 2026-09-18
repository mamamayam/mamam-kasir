import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Sliding-capsule segmented control per the component standards doc
/// §12 — for 2–3 options that must fit side by side, full-width. One
/// solid pill glides between options via [AnimatedPositioned] (rather
/// than each option carrying its own background), with equal-width
/// segments via [LayoutBuilder] + [Expanded].
///
/// Originally built for HPP & Stok Opname's Riwayat/Input Baru sub-tab
/// and its 3-option Bahan Baku/Setengah Jadi/Bahan Jadi switcher — now
/// the shared widget for any 2–3 option segmented control app-wide. For
/// 4+ scrollable options, use [DateFilterTabs] instead — don't invent a
/// third tab pattern.
class SlidingPillTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SlidingPillTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth - 8) / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: segmentWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                ),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  final isSelected = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelected(i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: labels.length > 2 ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                          child: Text(labels[i], textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
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
    );
  }
}
