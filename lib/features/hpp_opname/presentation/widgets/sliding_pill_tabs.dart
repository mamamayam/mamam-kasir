import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Sliding-capsule segmented control — one solid pill that glides
/// between options via [AnimatedPositioned], rather than each option
/// carrying its own background. Ported from the HTML mockup's
/// `.pill-indicator` mechanism (which measured DOM rects with JS);
/// Flutter's [LayoutBuilder] + equal-width [Expanded] segments makes the
/// same visual result reachable without manual measurement.
///
/// Used for both the 2-option Riwayat/Input Baru sub-tab and the
/// 3-option Bahan Baku/Setengah Jadi/Bahan Jadi category switcher.
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
