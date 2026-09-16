import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../application/arus_kas_provider.dart';
import '../domain/arus_kas_models.dart';
import 'widgets/add_arus_kas_modal.dart';
import 'widgets/arus_kas_entry_tile.dart';
import 'widgets/arus_kas_header.dart';

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
            ArusKasHeader(
              currentDirection: state.direction,
              onDirectionSelected: controller.setDirection,
              onBack: () => Navigator.of(context).pop(),
              onAdd: () => AppNav.showModal(context, builder: (_) => const AddArusKasModal()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _TotalCard(direction: state.direction, total: state.total),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DateFilterRow(
              current: state.dateFilter,
              customDate: state.customDate,
              onSelect: (filter) async {
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
                                  child: Center(
                                    child: Text(
                                      isPemasukan ? 'Belum ada pemasukan pada periode ini.' : 'Belum ada pengeluaran pada periode ini.',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: color.withValues(alpha: 0.2))),
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
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  final ArusKasDateFilter current;
  final DateTime? customDate;
  final ValueChanged<ArusKasDateFilter> onSelect;

  const _DateFilterRow({required this.current, required this.customDate, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: ArusKasDateFilter.values.map((filter) {
          final selected = filter == current;
          final label = filter == ArusKasDateFilter.pilihTanggal && selected && customDate != null
              ? '${customDate!.day}/${customDate!.month}/${customDate!.year}'
              : _dateFilterLabels[filter]!;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: InkWell(
              onTap: () => onSelect(filter),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: selected ? AppColors.brand : AppColors.border),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
