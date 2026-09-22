import 'package:flutter/material.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/placeholder_screen.dart';
import '../../arus_kas/presentation/arus_kas_screen.dart';
import '../../cabang/presentation/manajemen_cabang_screen.dart';
import '../../dompet/presentation/dompet_screen.dart';
import '../../hpp_opname/presentation/hpp_opname_screen.dart';
import '../../menu_management/presentation/menu_management_screen.dart';
import '../../pelanggan/presentation/pelanggan_screen.dart';
import '../../pengaturan/presentation/pengaturan_screen.dart';
import 'placeholders/laporan_mockup_placeholder_screen.dart';

/// One tile in the swipe-up menu's 3x3 grid.
class MenuGridItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const MenuGridItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// The 3x3 grid, kept 1:1 with the supplied React mockup's item set and
/// order (Dompet, Menu, Cabang, Kas, Pelanggan, Laporan, Staff, HPP,
/// Pengaturan) — colors are the toned-down muted palette (see AppColors
/// doc comment), not the mockup's fully-saturated set. Icons are Material
/// equivalents of the mockup's lucide-react icons.
///
/// Navigation model (stack semantics — see [[mamam-kasir-flutter]] notes):
/// every tile pushes a destination via [AppNav.push] WITHOUT dismissing
/// the bottom sheet first. The sheet is its own route underneath the
/// pushed screen in the same Navigator stack, so popping the destination
/// screen naturally reveals the sheet again, still open, exactly where
/// it was — no re-tap of the swipe-up trigger needed.
///
/// "Menu" opens its real, fully-built screen ([MenuManagementScreen] —
/// the reference pattern for future feature screens); the rest open a
/// shared [PlaceholderScreen] so nothing feels empty on tap. Placeholders
/// get swapped for real feature screens one at a time later, without
/// changing how they're reached.
List<MenuGridItem> buildMenuGridItems({
  required BuildContext context,
  required VoidCallback onDismissSheet,
}) {
  void pushDestination(WidgetBuilder builder) => AppNav.push(context, builder);

  MenuGridItem placeholderTile({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return MenuGridItem(
      label: label,
      icon: icon,
      color: color,
      onTap: () => pushDestination(
        (_) => PlaceholderScreen(title: label, icon: icon, accentColor: color),
      ),
    );
  }

  return [
    MenuGridItem(
      label: 'Dompet',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.tileDompet,
      onTap: () => pushDestination((_) => const DompetScreen()),
    ),
    MenuGridItem(
      label: 'Menu',
      icon: Icons.inventory_2_rounded,
      color: AppColors.tileMenu,
      onTap: () => pushDestination((_) => const MenuManagementScreen()),
    ),
    // Laba Rugi used to sit here pointing at a PlaceholderScreen. It is
    // a report, so it now lives behind Laporan's report-type picker
    // (ReportType.labaRugi) instead of owning a grid tile, and this slot
    // went to Cabang.
    MenuGridItem(
      label: 'Cabang',
      icon: Icons.storefront_rounded,
      color: AppColors.tileCabang,
      onTap: () => pushDestination((_) => const ManajemenCabangScreen()),
    ),
    MenuGridItem(
      label: 'Kas',
      icon: Icons.compare_arrows_rounded,
      color: AppColors.tileKas,
      onTap: () => pushDestination((_) => const ArusKasScreen()),
    ),
    MenuGridItem(
      label: 'Pelanggan',
      icon: Icons.people_alt_rounded,
      color: AppColors.tilePelanggan,
      onTap: () => pushDestination((_) => const PelangganScreen()),
    ),
    // Temporarily points at a static mockup placeholder (no DB/provider
    // wiring) instead of the real LaporanScreen, which is currently
    // broken. Swap back to LaporanScreen once it's fixed; see doc
    // comment on LaporanMockupPlaceholderScreen.
    MenuGridItem(
      label: 'Laporan',
      icon: Icons.pie_chart_rounded,
      color: AppColors.tileLaporan,
      onTap: () => pushDestination((_) => const LaporanMockupPlaceholderScreen()),
    ),
    placeholderTile(label: 'Staff', icon: Icons.badge_rounded, color: AppColors.tileStaff),
    MenuGridItem(
      label: 'HPP',
      icon: Icons.calculate_rounded,
      color: AppColors.tileHpp,
      onTap: () => pushDestination((_) => const HppOpnameScreen()),
    ),
    MenuGridItem(
      label: 'Pengaturan',
      icon: Icons.settings_rounded,
      color: AppColors.tilePengaturan,
      onTap: () => pushDestination((_) => const PengaturanScreen()),
    ),
  ];
}
