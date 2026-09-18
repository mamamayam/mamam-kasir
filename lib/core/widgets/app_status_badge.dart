import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared status/tag badge per the component standards doc §10:
/// [AppRadius.sm], padding 8 horizontal / 4 vertical, font 10/w800 with
/// letter-spacing 0.2–0.3, colored from [color] at 0.08–0.1 opacity as
/// the background and full [color] as the text/foreground.
///
/// Pass a semantic color from [AppColors] (e.g. [AppColors.success],
/// [AppColors.danger], [AppColors.warning]) — this widget derives the
/// tinted background from whatever [color] it's given.
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const AppStatusBadge(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.25, color: color),
      ),
    );
  }
}
