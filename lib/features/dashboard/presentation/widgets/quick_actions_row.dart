import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onKasirTap;
  final VoidCallback onRiwayatTap;

  const QuickActionsRow({super.key, required this.onKasirTap, required this.onRiwayatTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.shopping_cart_rounded,
            iconColor: AppColors.brand,
            title: 'Kasir',
            subtitle: 'Buka transaksi baru',
            onTap: onKasirTap,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickAction(
            icon: Icons.history_rounded,
            iconColor: AppColors.info,
            title: 'Riwayat',
            subtitle: 'Transaksi hari ini',
            onTap: onRiwayatTap,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
