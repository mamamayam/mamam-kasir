import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/session/app_session.dart';
import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../hrd/application/hrd_provider.dart';
import '../../hrd/presentation/owner/hrd_owner_approval_screen.dart';
import '../../hrd/presentation/staff/hrd_staff_entry_screen.dart';
import 'menu_action_card.dart';
import 'menu_grid_items.dart';

/// Shows the swipe-up menu as a modal bottom sheet. Call this instead of
/// building the sheet inline so the trigger (pill / swipe gesture) stays
/// decoupled from the sheet's own content.
///
/// `unreadNotifications` defaults to 0 — there is no notifications table
/// yet (see DashboardState's doc comment), so callers without a real
/// source can omit it rather than needing to construct a whole summary
/// object just to pass zero. The Approval card's badge count is read
/// live from [hrdControllerProvider] instead of being passed in, since a
/// real pending-approvals count now exists (see [HrdOwnerApprovalScreen]).
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
}) {
  return AppNav.showModal(
    context,
    builder: (context) => MenuBottomSheetContent(unreadNotifications: unreadNotifications),
  );
}

class MenuBottomSheetContent extends ConsumerWidget {
  final int unreadNotifications;
  const MenuBottomSheetContent({super.key, required this.unreadNotifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingApprovals = ref.watch(hrdControllerProvider.select((s) => s.pendingApprovals.length));
    final role = ref.watch(appSessionProvider.select((s) => s.role));
    final isOwner = role == AppRole.owner;

    // For this pass the 9-tile grid is Owner-only — Staff's access is
    // limited to Kasir/Riwayat (dashboard quick actions, not this sheet)
    // plus the "Staff" card below. See [[mamam-kasir-flutter]] notes:
    // per-tile custom permissions are a future Owner-facing feature, not
    // built yet, so this is a hard role check rather than a granular one.
    final items = isOwner
        ? buildMenuGridItems(
            context: context,
            onDismissSheet: () => Navigator.of(context).pop(),
          )
        : const <MenuGridItem>[];

    // Renamed from "Cek Gaji Saya" — this card doubles as the Staff PIN
    // flow entry point (pick employee -> PIN -> payslip), deliberately
    // separate from the Owner-only "Staff" grid tile (see
    // HrdEntryScreen's doc comment). Open to anyone on the shared
    // device; label/position just changes by who's logged in.
    final staffCard = MenuActionCard(
      icon: Icons.payments_rounded,
      title: 'Staff',
      subtitle: 'Rincian & lainnya',
      onTap: () => AppNav.push(context, (_) => const HrdStaffEntryScreen()),
    );
    final notifikasiCard = MenuActionCard(
      icon: Icons.notifications_rounded,
      title: 'Notifikasi',
      subtitle: '$unreadNotifications belum dibaca',
      onTap: () => Navigator.of(context).pop(),
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
                    if (isOwner) ...[
                      // Owner: Notifikasi + Approval side by side, "Staff"
                      // full-width below — unchanged from before, only the
                      // bottom card's label changed.
                      Row(
                        children: [
                          notifikasiCard,
                          const SizedBox(width: AppSpacing.md),
                          MenuActionCard(
                            icon: Icons.fact_check_rounded,
                            title: 'Approval',
                            subtitle: '$pendingApprovals menunggu',
                            onTap: () => AppNav.push(context, (_) => const HrdOwnerApprovalScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(children: [staffCard]),
                    ] else ...[
                      // Staff: no Approval access — "Staff" takes
                      // Approval's old slot, both equal-width side by side.
                      Row(
                        children: [
                          notifikasiCard,
                          const SizedBox(width: AppSpacing.md),
                          staffCard,
                        ],
                      ),
                    ],
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: AppSpacing.xl),
                      // 3x3 grid — Owner only, see isOwner check above.
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
