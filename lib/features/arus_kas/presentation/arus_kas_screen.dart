import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_card_shell.dart';
import '../../../core/widgets/app_dropdown_title.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/date_filter_tabs.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/arus_kas_provider.dart';
import '../domain/arus_kas_models.dart';
import 'widgets/add_arus_kas_modal.dart';
import 'widgets/arus_kas_entry_tile.dart';

const _dateFilterOptions = [
  ArusKasDateFilter.hariIni,
  ArusKasDateFilter.kemarin,
  ArusKasDateFilter.bulanIni,
  ArusKasDateFilter.bulanKemarin,
  ArusKasDateFilter.pilihTanggal,
];

const _dateFilterLabels = {
  ArusKasDateFilter.hariIni: 'Hari Ini',
  ArusKasDateFilter.kemarin: 'Kemarin',
  ArusKasDateFilter.bulanIni: 'Bulan Ini',
  ArusKasDateFilter.bulanKemarin: 'Bulan Kemarin',
  ArusKasDateFilter.pilihTanggal: 'Pilih Tanggal',
};

/// Arus Kas (cash flow / Pemasukan-Pengeluaran) screen — reached from
/// the swipe-up menu's "Kas" tile. Reference-pattern layout, same as
/// Menu Management: dropdown title switch + add button, date-filter
/// row, list of entries, floating "Tambah" modal form.
///
/// Cash-location-funded entries are wired into the Dompet ledger via
/// ArusKasRepository so Dompet balances and Arus Kas totals stay
/// traceable to each other (see [[mamam-kasir-flutter]] notes).
class ArusKasScreen extends ConsumerWidget {
  const ArusKasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(arusKasProvider);
    final controller = ref.read(arusKasProvider.notifier);

    ref.listen(arusKasProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.danger));
      }
    });

    final isPemasukan = state.direction == ArusKasDirection.pemasukan;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(
              title: AppDropdownTitle<ArusKasDirection>(
                selected: state.direction,
                options: const [ArusKasDirection.pemasukan, ArusKasDirection.pengeluaran],
                labelBuilder: (d) => d == ArusKasDirection.pemasukan ? 'Pemasukan' : 'Pengeluaran',
                onSelected: controller.setDirection,
              ),
              trailingIcon: Icons.add_rounded,
              onTrailingTap: () => AppNav.showModal(context, builder: (_) => const AddArusKasModal()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _TotalCard(direction: state.direction, total: state.total),
            ),
            const SizedBox(height: AppSpacing.sm),
            DateFilterTabs<ArusKasDateFilter>(
              options: _dateFilterOptions,
              selected: state.dateFilter,
              labelBuilder: (filter) {
                if (filter == ArusKasDateFilter.pilihTanggal && state.dateFilter == filter && state.customDate != null) {
                  final d = state.customDate!;
                  return '${d.day}/${d.month}/${d.year}';
                }
                return _dateFilterLabels[filter]!;
              },
              onSelected: (filter) async {
                if (filter == ArusKasDateFilter.pilihTanggal) {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.customDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) controller.setDateFilter(filter, customDate: picked);
                } else {
                  controller.setDateFilter(filter);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: controller.load,
                      child: state.entries.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                                  child: AppEmptyState(
                                    icon: Icons.receipt_long_rounded,
                                    title: isPemasukan ? 'Belum ada pemasukan' : 'Belum ada pengeluaran',
                                    subtitle: 'Belum ada catatan pada periode ini.',
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                              children: [
                                AppCardShell(
                                  child: Column(
                                    children: state.entries
                                        .map((e) => ArusKasEntryTile(entry: e, onDelete: () => controller.deleteEntry(e.id)))
                                        .toList(),
                                  ),
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

class _TotalCard extends StatelessWidget {
  final ArusKasDirection direction;
  final int total;
  const _TotalCard({required this.direction, required this.total});

  @override
  Widget build(BuildContext context) {
    final isPemasukan = direction == ArusKasDirection.pemasukan;
    final color = isPemasukan ? AppColors.success : AppColors.danger;
    return AppCardShell(
      backgroundColor: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.2),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPemasukan ? 'TOTAL PEMASUKAN' : 'TOTAL PENGELUARAN',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(formatRupiah(total), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
