import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// iOS-style page header: a floating circular back button, a centered
/// title, and an optional floating circular action button on the right
/// (e.g. "..." menu, add, or a dropdown trigger). No bottom border/bar —
/// the header sits directly on [AppColors.background].
///
/// Used by full-page screens reached via [Navigator.push] (Riwayat,
/// transaction detail, Menu Management, and the placeholder screens for
/// swipe-up grid tiles like Laporan). Bottom sheets / modals (Checkout,
/// variant picker, etc.) keep their own close-icon header and are not
/// affected by this widget.
class IosPageHeader extends StatelessWidget implements PreferredSizeWidget {
  /// The title widget, typically a [Text]. Kept as a widget (rather than
  /// a plain string) so callers needing a tappable title with a dropdown
  /// chevron (e.g. Menu Management) can still center it the same way.
  final Widget title;
  final VoidCallback? onBack;

  /// Icon shown in the right-side circular button. Null hides the button
  /// entirely, letting the title center against the back button alone.
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  /// Custom right-side widget, for the rare header whose action button
  /// needs more than a plain icon (e.g. Manajemen Cabang's "+" with a
  /// premium badge overlaid on it). Takes precedence over
  /// [trailingIcon]/[onTrailingTap] when set.
  ///
  /// This is an extension point, not an escape hatch: build it out of
  /// the standard 44x44 circular button (`AppIconButton.standard`) so
  /// the header keeps one shape everywhere, per component standards §6.
  final Widget? trailing;

  const IosPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                child: title,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: onBack ?? () => Navigator.of(context).pop(),
              ),
            ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing!)
            else if (trailingIcon != null)
              Align(
                alignment: Alignment.centerRight,
                child: _CircleIconButton(icon: trailingIcon!, onTap: onTrailingTap),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: 24, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
