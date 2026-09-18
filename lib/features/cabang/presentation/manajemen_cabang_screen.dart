import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card_shell.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/cabang_provider.dart';
import '../domain/cabang_models.dart';

/// Manajemen Cabang (Manajemen Toko) — reached from the swipe-up grid's
/// Cabang tile, the slot Laba Rugi used to occupy before it moved into
/// Laporan as a report type.
///
/// Ported from the supplied reference screenshot: header with a back
/// button and a "+" carrying a premium badge, a three-up stat row (Maks
/// Toko / Toko / Aktif), then one card per outlet with its address,
/// phone and an AKTIF/NONAKTIF status badge.
///
/// What is real and what is not, on purpose:
/// - The list, the counts and the status toggle all read/write the
///   `branches` table. Nothing on this screen is a hardcoded constant.
/// - "Maks Toko" is [kDefaultMaxBranches], a single constant. The PRD
///   has no subscription/plan tiering, so the ceiling is not invented as
///   a billing rule — the "+" simply explains it is unavailable rather
///   than opening a create form that cannot honour a limit nobody has
///   specified yet.
class ManajemenCabangScreen extends ConsumerWidget {
  const ManajemenCabangScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cabangProvider);
    final controller = ref.read(cabangProvider.notifier);
    final summary = state.summary;

    ref.listen(cabangProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.danger),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(
              title: const Text('Manajemen Toko'),
              trailing: _AddBranchButton(
                isLocked: summary.isAtLimit,
                onTap: () => _onAddTapped(context, summary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(child: _SummaryCard(value: '${summary.maxBranches}', label: 'Maks Toko')),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _SummaryCard(value: '${summary.totalBranches}', label: 'Toko')),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _SummaryCard(value: '${summary.activeBranches}', label: 'Aktif')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: controller.load,
                      child: state.branches.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                children: [
                                  SizedBox(
                                    height: constraints.maxHeight,
                                    child: const Center(
                                      child: AppEmptyState(
                                        icon: Icons.storefront_rounded,
                                        title: 'Tidak ada data',
                                        subtitle: 'Belum ada cabang yang terdaftar.',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                              itemCount: state.branches.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final branch = state.branches[index];
                                return _BranchCard(
                                  branch: branch,
                                  onTap: () => _confirmToggle(context, controller, branch),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddTapped(BuildContext context, CabangSummary summary) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          summary.isAtLimit
              ? 'Batas maksimal ${summary.maxBranches} toko sudah tercapai.'
              : 'Tambah cabang belum tersedia.',
        ),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _confirmToggle(BuildContext context, CabangController controller, Cabang branch) async {
    final willActivate = !branch.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(willActivate ? 'Aktifkan Toko?' : 'Nonaktifkan Toko?'),
        content: Text(
          willActivate
              ? '${branch.name} akan kembali aktif dan bisa dipakai bertransaksi.'
              : '${branch.name} tidak bisa dipakai bertransaksi. Semua riwayatnya tetap tersimpan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              willActivate ? 'Aktifkan' : 'Nonaktifkan',
              style: TextStyle(color: willActivate ? AppColors.success : AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) await controller.toggleActive(branch);
  }
}

/// The "+" button. When the branch ceiling is reached it keeps the same
/// 44x44 circular shape (component standards §6) and overlays a small
/// badge in the corner, matching the reference screenshot.
class _AddBranchButton extends StatelessWidget {
  final bool isLocked;
  final VoidCallback onTap;

  const _AddBranchButton({required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final button = AppIconButton.standard(icon: Icons.add_rounded, onTap: onTap);
    if (!isLocked) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
            child: const Icon(Icons.star_rounded, size: 11, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Cabang branch;
  final VoidCallback onTap;

  const _BranchCard({required this.branch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Not AppItemThumbnail: standards §9 scopes the initials avatar
          // to product thumbnails specifically. A branch gets a plain
          // storefront glyph, built from the same radius/color tokens.
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.storefront_rounded, size: 24, color: AppColors.textMuted),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                if (branch.hasAddress) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    branch.displayAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                ],
                if (branch.hasPhone) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          branch.displayPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppStatusBadge(
            branch.isActive ? 'Aktif' : 'Nonaktif',
            branch.isActive ? AppColors.success : AppColors.danger,
          ),
        ],
      ),
    );
  }
}
