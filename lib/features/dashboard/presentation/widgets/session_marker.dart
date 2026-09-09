import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/dashboard_models.dart';

/// "Who's logged in" line shown under the store name in the header, e.g.
/// "● Owner • Budi S." — visible and legible (per the latest mockup) but
/// kept in muted gray text rather than a bold/colored treatment, per the
/// toned-down palette decision.
class SessionMarker extends StatelessWidget {
  final SessionUser user;
  const SessionMarker({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '${user.role} • ${user.name}',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
