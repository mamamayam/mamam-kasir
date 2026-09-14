import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared header for bottom sheets / modals (Checkout, Pembayaran, picker
/// sheets, etc.) — a circular close/back button on the left, a centered
/// title, and an optional trailing widget on the right.
///
/// This exists specifically to prevent title/button collisions. The old
/// pattern (repeated independently in several sheet files) used
/// `Stack` + `Center` for the title and `Align(centerLeft)` for the close
/// button: both are positioned independently of each other, so a long
/// title or a narrow screen let them overlap instead of making room for
/// one another.
///
/// This widget uses a `Row` instead: the close button and the trailing
/// slot are fixed-width, the title sits in an `Expanded` between them and
/// is truncated with an ellipsis rather than ever overflowing or
/// colliding. Even with no [trailing], a same-size invisible spacer is
/// reserved on the right so the title stays visually centered against the
/// close button, matching [IosPageHeader]'s look for full-page screens.
///
/// NOTE FOR FUTURE WORK: every sheet/modal header MUST use this widget
/// (or wrap it). Do not hand-roll a new header with `Stack` +
/// `Center` + `Align` — that combination is exactly what caused the
/// title-collision bug this widget was created to fix. If an existing
/// sheet needs a different header shape, extend/parameterize
/// [AppSheetHeader] rather than reimplementing it from scratch. Full-page
/// screens (reached via [Navigator.push]) should keep using
/// [IosPageHeader] instead — the two are intentionally separate widgets
/// for two different navigation layers (see [IosPageHeader]'s doc
/// comment), but both must stay collision-safe the same way.
class AppSheetHeader extends StatelessWidget {
  /// Title text. Always single-line with an ellipsis — see class doc.
  final String title;

  /// Called when the close/back button is tapped. Defaults to
  /// `Navigator.of(context).pop()` when omitted. Pass a custom callback
  /// when the sheet needs to run extra logic before closing (e.g.
  /// resetting a provider) — see `PaymentModal` for an example.
  final VoidCallback? onClose;

  /// Icon for the left button. Defaults to a close ("X") icon, matching
  /// the sheets this widget was extracted from. Pass
  /// `Icons.chevron_left_rounded` for a back-style sheet header instead.
  final IconData closeIcon;

  /// Optional widget shown on the right, same reserved width as the
  /// close button so the title stays centered either way.
  final Widget? trailing;

  const AppSheetHeader({
    super.key,
    required this.title,
    this.onClose,
    this.closeIcon = Icons.close_rounded,
    this.trailing,
  });

  static const double _buttonSize = 44;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: SizedBox(
        height: _buttonSize,
        child: Row(
          children: [
            _CircleIconButton(
              icon: closeIcon,
              onTap: onClose ?? () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const SizedBox(width: _buttonSize),
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
          width: AppSheetHeader._buttonSize,
          height: AppSheetHeader._buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
