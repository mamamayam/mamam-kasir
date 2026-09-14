import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/dashboard_models.dart';

/// "Who's logged in" line shown under the store name in the header, e.g.
/// "● Owner • Budi S." once a real Auth/Staff module provides a name and
/// role. Renders nothing at all when both are unset (see [SessionUser]'s
/// doc comment) rather than showing a placeholder "null • null" line.
class SessionMarker extends StatelessWidget {
  final SessionUser user;
  const SessionMarker({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.name == null && user.role == null) return const SizedBox.shrink();

    final label = [user.role, user.name].where((s) => s != null && s.isNotEmpty).join(' • ');

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
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
