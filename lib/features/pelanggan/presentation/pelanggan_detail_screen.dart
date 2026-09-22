import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/pelanggan_provider.dart';
import '../domain/pelanggan_logic.dart';
import '../domain/pelanggan_models.dart';
import 'pelanggan_form_screen.dart';
import 'widgets/pelanggan_cards.dart';
import 'widgets/pelanggan_chrome.dart';

/// Detail Pelanggan — record-list style (icon + small muted label + bold
/// value, hairline separated), NOT a hero card with a big avatar, per the
/// approved mockup / handoff doc.
///
/// PLACEHOLDER PHASE: riwayat + omzet numbers are static dummy data, and
/// the period chips are a visual toggle only (the dummy data isn't
/// filtered) — same as the approved mockup. Reached via [AppNav.push].
class PelangganDetailScreen extends ConsumerStatefulWidget {
  final int customerId;
  const PelangganDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<PelangganDetailScreen> createState() => _PelangganDetailScreenState();
}

class _PelangganDetailScreenState extends ConsumerState<PelangganDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Every freshly opened detail starts on "Semua Waktu" (as the mockup).
    // Deferred so we don't mutate provider state during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pelangganProvider.notifier).resetPeriod();
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
  }

  Future<void> _edit(Pelanggan customer) async {
    final saved = await AppNav.push<bool>(context, (_) => PelangganFormScreen(editingId: customer.id));
    if (!mounted) return;
    if (saved == true) _showSnack('Perubahan disimpan');
  }

  Future<void> _confirmDelete(Pelanggan customer) async {
    final confirmed = await AppNav.showModal<bool>(
      context,
      isScrollControlled: false,
      builder: (_) => _DeleteSheet(name: customer.name),
    );
    if (confirmed != true || !mounted) return;

    // ORDER MATTERS: capture what we need, pop first, delete second.
    // If we deleted first, this screen's build() would re-run with
    // `byId()` == null and paint an empty Scaffold for the whole
    // 280ms slide-out animation of the pop (visible blank flash).
    // Popping first keeps the fully-rendered detail sliding away; the
    // data is removed right after, when this screen is already leaving.
    //
    // This relies on `pelangganProvider` being autoDispose AND still
    // watched by a screen underneath us after the pop. That holds today:
    // the only entry point to this feature is `PelangganScreen` (menu
    // tile), which always sits at the bottom of the stack and watches the
    // provider. If this detail page ever gets a second entry point that
    // is NOT under PelangganScreen (e.g. opened straight from the POS),
    // the provider could be disposed before `delete()` runs and throw —
    // keep the provider alive there (ref.keepAlive / a non-autoDispose
    // provider) before adding that entry point.
    final notifier = ref.read(pelangganProvider.notifier);
    final id = customer.id;
    Navigator.of(context).pop();
    notifier.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pelangganProvider);
    final controller = ref.read(pelangganProvider.notifier);
    final customer = state.byId(widget.customerId);

    // Deleted (or unknown) while this page was open — render nothing
    // rather than crash; the pop above closes the page right after.
    if (customer == null) {
      return const Scaffold(backgroundColor: AppColors.pelangganBackground);
    }

    final rank = PelangganLogic.rankOf(state.customers, customer);
    final hasOmzet = customer.omzet > 0;
    final last = customer.lastPurchase;

    return Scaffold(
      backgroundColor: AppColors.pelangganBackground,
      body: SafeArea(
        child: Column(
          children: [
            PelangganHeader(
              title: 'Detail Pelanggan',
              onLeadingTap: () => Navigator.of(context).pop(),
              trailingIcon: Icons.edit_outlined,
              onTrailingTap: () => _edit(customer),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  PelangganRecordCard(
                    rows: [
                      PelangganRecordRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Nama',
                        value: customer.name,
                      ),
                      PelangganRecordRow(
                        icon: Icons.call_outlined,
                        label: 'Nomor HP',
                        value: customer.phones.isNotEmpty ? customer.phones.join(', ') : '—',
                      ),
                      PelangganRecordRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: customer.address.isNotEmpty ? customer.address : '—',
                      ),
                    ],
                  ),
                  PelangganRankCard(
                    title: hasOmzet ? 'Peringkat #$rank Pelanggan Paling Loyal' : 'Belum memiliki transaksi',
                    subtitle: 'dari ${state.customers.length} pelanggan',
                  ),
                  const PelangganSectionTitle('Ringkasan Omzet'),
                  PelangganChipRow<PelangganPeriod>(
                    options: PelangganPeriod.values,
                    selected: state.period,
                    labelBuilder: (p) => p.label,
                    onSelected: controller.setPeriod,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PelangganRecordCard(
                    rows: [
                      PelangganRecordRow(
                        icon: Icons.payments_outlined,
                        label: 'Total Omzet',
                        value: PelangganLogic.formatRp(customer.omzet),
                      ),
                      PelangganRecordRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Total Transaksi',
                        value: '${customer.trxCount} transaksi',
                      ),
                      PelangganRecordRow(
                        icon: Icons.bar_chart_rounded,
                        label: 'Rata-rata per Transaksi',
                        value: PelangganLogic.formatRp(
                          customer.trxCount > 0 ? (customer.omzet / customer.trxCount).round() : 0,
                        ),
                      ),
                      PelangganRecordRow(
                        icon: Icons.schedule_rounded,
                        label: 'Transaksi Terakhir',
                        value: last != null ? '${last.date} — ${last.time}' : 'Belum ada transaksi',
                      ),
                    ],
                  ),
                  const PelangganSectionTitle('Riwayat Pembelian'),
                  if (customer.history.isEmpty)
                    const PelangganRiwayatEmpty()
                  else ...[
                    for (final entry in customer.history) PelangganRiwayatCard(entry: entry),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                    child: _DangerButton(
                      label: 'Hapus Pelanggan',
                      icon: Icons.delete_outline_rounded,
                      onTap: () => _confirmDelete(customer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width red pill button (mockup `.btn-solid.danger`: padding 17,
/// 15.5/w700, radius pill, 8px icon gap).
class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pelangganDanger,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delete confirmation, shown as a Level-2 bottom sheet (mockup
/// `.modal-sheet`) via [AppNav.showModal]. Pops `true` on confirm.
///
/// PLACEHOLDER copy: the mockup says the data "akan dihapus ... tidak
/// bisa dibatalkan". That is NOT final behaviour — AGENTS.md forbids hard
/// deleting master data that history references (use Nonaktif), and the
/// handoff lists this as an open Product Owner decision. Kept here only
/// because the mockup shows it and this phase is a visual placeholder.
class _DeleteSheet extends StatelessWidget {
  final String name;
  const _DeleteSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.pelangganBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.pelangganDanger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 26, color: AppColors.pelangganDanger),
            ),
            const SizedBox(height: 14),
            const Text(
              'Hapus pelanggan ini?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.pelangganTextPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Data dan riwayat "$name" akan dihapus dari daftar. Tindakan ini tidak bisa dibatalkan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 17),
                        child: Center(
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pelangganTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: AppColors.pelangganDanger,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(true),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 17),
                        child: Center(
                          child: Text(
                            'Hapus',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
