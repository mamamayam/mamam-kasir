import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../../../core/widgets/placeholder_screen.dart';
import '../../auth/presentation/pin_login_screen.dart';
import '../application/auto_print_provider.dart';

/// Pengaturan (Settings) screen, ported 1:1 from the approved HTML
/// mockup's layout (account card + grouped rows). Per that mockup's
/// scope, Bahasa/Mata Uang/Pajak and the Bantuan & Legal group were
/// explicitly removed and are not reproduced here.
///
/// Rows fall into three buckets:
/// - Real and wired: Cetak Struk Otomatis (SharedPreferences), Keluar
///   Akun (returns to PIN login).
/// - Real status, no action yet: Status Sinkronisasi (this app is
///   local-first with no cloud sync built — shown as "Tidak aktif"
///   rather than inventing a sync state), Printer Bluetooth (no
///   Bluetooth library wired up yet — shown as "Tidak tersambung").
/// - Not yet built, routed to [PlaceholderScreen]: Kelola Karyawan (no
///   Staff module exists), Backup & Restore (no such feature exists).
/// Keamanan PIN links to the existing PIN login flow's settings — since
/// there is no separate "change PIN" screen yet, it also routes to a
/// placeholder rather than inventing one.
class PengaturanScreen extends ConsumerWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoPrint = ref.watch(autoPrintReceiptProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Pengaturan')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  const _AccountCard(),
                  const SizedBox(height: AppSpacing.xl),
                  const _GroupLabel('Akun & Keamanan'),
                  _GroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Keamanan PIN',
                        onTap: () => AppNav.push(
                          context,
                          (_) => const PlaceholderScreen(
                            title: 'Keamanan PIN',
                            icon: Icons.lock_outline_rounded,
                            accentColor: AppColors.textPrimary,
                            description: 'Pengaturan ganti PIN akan segera hadir.',
                          ),
                        ),
                      ),
                      _SettingsRow(
                        icon: Icons.people_alt_outlined,
                        label: 'Kelola Karyawan',
                        onTap: () => AppNav.push(
                          context,
                          (_) => const PlaceholderScreen(
                            title: 'Kelola Karyawan',
                            icon: Icons.people_alt_outlined,
                            accentColor: AppColors.tileStaff,
                            description: 'Manajemen karyawan & role akan segera hadir.',
                          ),
                        ),
                      ),
                      _SettingsRow(
                        icon: Icons.sync_rounded,
                        label: 'Status Sinkronisasi',
                        trailingText: 'Tidak aktif',
                        onTap: () => AppNav.push(
                          context,
                          (_) => const PlaceholderScreen(
                            title: 'Status Sinkronisasi',
                            icon: Icons.sync_rounded,
                            accentColor: AppColors.textMuted,
                            description: 'Aplikasi ini berjalan local-first. Sinkronisasi cloud belum tersedia.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _GroupLabel('Perangkat'),
                  _GroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.bluetooth_rounded,
                        label: 'Printer Bluetooth',
                        trailingText: 'Tidak tersambung',
                        onTap: () => AppNav.push(
                          context,
                          (_) => const PlaceholderScreen(
                            title: 'Printer Bluetooth',
                            icon: Icons.bluetooth_rounded,
                            accentColor: AppColors.info,
                            description: 'Koneksi printer struk thermal akan segera hadir.',
                          ),
                        ),
                      ),
                      _SettingsRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'Cetak Struk Otomatis',
                        trailing: Switch(
                          value: autoPrint,
                          onChanged: (_) => ref.read(autoPrintReceiptProvider.notifier).toggle(),
                          activeColor: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _GroupLabel('Data & Backup'),
                  _GroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.cloud_upload_outlined,
                        label: 'Backup & Restore',
                        onTap: () => AppNav.push(
                          context,
                          (_) => const PlaceholderScreen(
                            title: 'Backup & Restore',
                            icon: Icons.cloud_upload_outlined,
                            accentColor: AppColors.info,
                            description: 'Backup & restore data akan segera hadir.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _GroupCard(
                    children: [
                      _SettingsRow(
                        icon: Icons.logout_rounded,
                        label: 'Keluar Akun',
                        labelColor: AppColors.danger,
                        iconColor: AppColors.danger,
                        showTrailingChevron: false,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Center(
                    child: Text('Mamam Kasir v1.0.0 (build 1)', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar Akun?'),
        content: const Text('Anda akan kembali ke halaman login PIN.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const PinLoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Account card — name + role badge + email, matching the mockup. Name/
/// email/role are static placeholders (no Staff/Auth module exists to
/// read a real logged-in identity from — same limitation noted on
/// [SessionUser] in the dashboard feature), shown here rather than left
/// blank so the card isn't empty; swap in real fields once that module
/// lands.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.textPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text('Mamam Ayam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppRadius.pill)),
                      child: const Text('PEMILIK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('mamamayamindonesia@gmail.com', style: TextStyle(fontSize: 13, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Container(
            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border))),
            child: entry.value,
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final String? trailingText;
  final Widget? trailing;
  final bool showTrailingChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.trailingText,
    this.trailing,
    this.showTrailingChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: iconColor ?? AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: labelColor ?? AppColors.textPrimary),
              ),
            ),
            if (trailingText != null) ...[
              Text(trailingText!, style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
              const SizedBox(width: 4),
            ],
            if (trailing != null) trailing!,
            if (trailing == null && showTrailingChevron)
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
