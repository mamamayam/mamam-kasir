import 'package:flutter/material.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'menu_action_card.dart';
import 'menu_grid_items.dart';

/// Shows the swipe-up menu as a modal bottom sheet. Call this instead of
/// building the sheet inline so the trigger (pill / swipe gesture) stays
/// decoupled from the sheet's own content.
///
/// `unreadNotifications`/`pendingApprovals` default to 0 — there is no
/// notifications/approvals table yet (see DashboardState's doc comment),
/// so callers without a real source for these can omit them rather than
/// needing to construct a whole summary object just to pass zeros.
///
/// Uses [AppNav.showModal] rather than a raw [showModalBottomSheet] —
/// this sheet is the reference case for the app's stack-navigation model
/// (see [buildMenuGridItems]'s doc comment): each tile pushes its
/// destination on top of this sheet via [AppNav.push] without closing it
/// first, so popping the destination reveals this sheet again exactly as
/// it was. That only works because this sheet is itself a proper route
/// in the same Navigator stack, which is what [AppNav.showModal]
/// guarantees.
Future<void> showMenuBottomSheet(
  BuildContext context, {
  int unreadNotifications = 0,
  int pendingApprovals = 0,
}) {
  return AppNav.showModal(
    context,
    builder: (context) => MenuBottomSheetContent(
      unreadNotifications: unreadNotifications,
      pendingApprovals: pendingApprovals,
    ),
  );
}

class MenuBottomSheetContent extends StatelessWidget {
  final int unreadNotifications;
  final int pendingApprovals;
  const MenuBottomSheetContent({super.key, required this.unreadNotifications, required this.pendingApprovals});

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
                          subtitle: '$unreadNotifications belum dibaca',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        MenuActionCard(
                          icon: Icons.fact_check_rounded,
                          title: 'Approval',
                          subtitle: '$pendingApprovals menunggu',
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
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.xs,
                      childAspectRatio: 1.0,
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(item.icon, size: 21, color: Colors.white),
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
