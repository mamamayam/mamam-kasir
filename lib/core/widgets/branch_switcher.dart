import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_nav.dart';
import '../session/app_session_provider.dart';
import '../session/branch_access_repository.dart';
import '../session/branch_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_sheet_header.dart';

/// Pill showing the active branch; tapping it opens [BranchSwitcherSheet]
/// to switch. Reusable anywhere a screen should show (and let the user
/// change) which branch its numbers belong to.
///
/// With zero or one accessible branch there is nothing to switch to, so
/// the pill is a plain label: no chevron, not tappable.
class BranchSwitcherPill extends ConsumerWidget {
  const BranchSwitcherPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBranchId = ref.watch(appSessionProvider.select((s) => s.branchId));
    final branchesAsync = ref.watch(accessibleBranchesProvider);
    final branches = branchesAsync.valueOrNull ?? const <AccessibleBranch>[];

    final active = branches.where((b) => b.id == activeBranchId).firstOrNull;
    final canSwitch = branches.length > 1;

    final String label;
    if (active != null) {
      label = active.name;
    } else if (branchesAsync.isLoading) {
      label = 'Memuat cabang...';
    } else if (branches.isEmpty) {
      label = 'Tanpa cabang';
    } else {
      label = 'Pilih cabang';
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          if (canSwitch) ...[
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
          ],
        ],
      ),
    );

    if (!canSwitch) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: () {
        // Fresh list every time the sheet opens, so a branch renamed or
        // switched off in Manajemen Cabang is reflected immediately.
        ref.invalidate(accessibleBranchesProvider);
        AppNav.showModal(context, isScrollControlled: false, builder: (_) => const BranchSwitcherSheet());
      },
      child: content,
    );
  }
}

/// "Pilih Cabang" bottom sheet: one row per accessible branch, a check on
/// the active one. Picking a row switches the session's active branch via
/// [AppSessionController.setActiveBranch] — which re-validates access —
/// and every branch-scoped screen reloads from the new session value.
class BranchSwitcherSheet extends ConsumerWidget {
  const BranchSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBranchId = ref.watch(appSessionProvider.select((s) => s.branchId));
    final branchesAsync = ref.watch(accessibleBranchesProvider);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: AppSheetHeader(title: 'Pilih Cabang'),
            ),
            Flexible(
              child: branchesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Text(
                    'Gagal memuat daftar cabang: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                data: (branches) => ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final branch in branches)
                      _BranchRow(
                        branch: branch,
                        isActive: branch.id == activeBranchId,
                        onTap: () => _select(context, ref, branch, activeBranchId),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref, AccessibleBranch branch, String? activeBranchId) async {
    if (branch.id == activeBranchId) {
      Navigator.of(context).pop();
      return;
    }

    final switched = await ref.read(appSessionProvider.notifier).setActiveBranch(branch.id);
    if (!context.mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switched ? 'Cabang aktif: ${branch.name}' : 'Tidak bisa pindah ke ${branch.name}'),
          backgroundColor: switched ? null : AppColors.danger,
        ),
      );
  }
}

class _BranchRow extends StatelessWidget {
  final AccessibleBranch branch;
  final bool isActive;
  final VoidCallback onTap;

  const _BranchRow({required this.branch, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive ? AppColors.brand.withValues(alpha: 0.12) : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_outlined, size: 19, color: isActive ? AppColors.brand : AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                branch.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            if (isActive) const Icon(Icons.check_rounded, size: 18, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }
}
