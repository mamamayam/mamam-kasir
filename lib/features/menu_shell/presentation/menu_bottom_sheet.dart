import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../dashboard/domain/dashboard_models.dart';
import 'menu_action_card.dart';
import 'menu_grid_items.dart';

/// Shows the swipe-up menu as a modal bottom sheet. Call this instead of
/// building the sheet inline so the trigger (pill / swipe gesture) stays
/// decoupled from the sheet's own content.
Future<void> showMenuBottomSheet(
  BuildContext context, {
  required DashboardSummary summary,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MenuBottomSheetContent(summary: summary),
  );
}

class MenuBottomSheetContent extends StatelessWidget {
  final DashboardSummary summary;
  const MenuBottomSheetContent({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = buildMenuGridItems(
      context: context,
      onDismissSheet: () => Navigator.of(context).pop(),
    );

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notifikasi / Approval row
                    Row(
                      children: [
                        MenuActionCard(
                          icon: Icons.notifications_rounded,
                          title: 'Notifikasi',
                          subtitle: '${summary.unreadNotifications} belum dibaca',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MenuActionCard(
                          icon: Icons.fact_check_rounded,
                          title: 'Approval',
                          subtitle: '${summary.pendingApprovals} menunggu',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: AppSpacing.xl),
                    // 3x3 grid
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.lg,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.82,
                      children: items.map((item) => _MenuGridTile(item: item)).toList(),
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

class _MenuGridTile extends StatelessWidget {
  final MenuGridItem item;
  const _MenuGridTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(item.icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
