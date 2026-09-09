import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A slim inline refresh row shown directly below the frozen header,
/// distinct from Flutter's default full-page [RefreshIndicator] spinner —
/// so refreshing reads as "just the content area is updating", not the
/// whole screen reloading.
class InlineRefreshIndicator extends StatelessWidget {
  final bool visible;
  final bool isRefreshing;

  const InlineRefreshIndicator({super.key, required this.visible, required this.isRefreshing});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: visible ? 34 : 0,
      curve: Curves.easeOut,
      color: AppColors.background,
      child: visible
          ? Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: isRefreshing
                        ? const CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted)
                        : const Icon(Icons.refresh_rounded, size: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRefreshing ? 'Memperbarui data...' : 'Menarik untuk refresh...',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
