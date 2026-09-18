import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum _AppIconButtonVariant { standard, stepper }

/// Shared round icon button — two fixed sizes per the component
/// standards doc §6.
///
/// - [AppIconButton.standard]: 44×44, icon size 20 by default (18–22
///   allowed) — filter, close, back, tambah (+), titik tiga.
/// - [AppIconButton.stepper]: 36×36, icon size 16 — qty +/- in cart,
///   variant picker steppers.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final _AppIconButtonVariant _variant;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppIconButton.standard({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
  }) : _variant = _AppIconButtonVariant.standard;

  const AppIconButton.stepper({
    super.key,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  })  : _variant = _AppIconButtonVariant.stepper,
        iconSize = null;

  @override
  Widget build(BuildContext context) {
    final size = _variant == _AppIconButtonVariant.standard ? 44.0 : 36.0;
    final resolvedIconSize = iconSize ?? (_variant == _AppIconButtonVariant.standard ? 20.0 : 16.0);

    return Material(
      color: backgroundColor ?? AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: onTap == null
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: resolvedIconSize, color: iconColor ?? (onTap == null ? AppColors.textMuted : AppColors.textPrimary)),
        ),
      ),
    );
  }
}
