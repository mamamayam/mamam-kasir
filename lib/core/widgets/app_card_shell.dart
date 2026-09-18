import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared card shell — the standard outer skin for any card in the app,
/// per the component standards doc §8: fill [AppColors.surface], radius
/// [AppRadius.lg], `border: Border.all(color: AppColors.border)`, inner
/// padding [AppSpacing.md] by default.
///
/// Wrap card content in this instead of writing
/// `Container(decoration: BoxDecoration(...))` by hand. Content inside
/// (titles, subtitles, figures) should still follow the typography
/// scale in §1 — this widget only owns the outer skin.
class AppCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  const AppCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: card,
      ),
    );
  }
}
