import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Generic placeholder screen for any feature not yet built out.
///
/// Used by the swipe-up menu's 3x3 grid tiles that don't have a real
/// destination yet (Dompet, Laba Rugi, Kas, Pelanggan, Laporan, Staff,
/// HPP) so tapping them never feels empty — each shows a consistent
/// header (back button + title + icon) and a simple "coming soon" body.
/// Real feature screens get ported in to replace this later, one at a
/// time, without touching how they're reached (still [AppNav.push]).
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final String? description;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Icon(icon, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description ?? 'Fitur ini akan segera hadir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
