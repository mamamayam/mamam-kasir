import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card_shell.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/laporan_provider.dart';
import '../domain/laporan_models.dart';
import 'widgets/month_picker_sheet.dart';
import 'widgets/report_trend_chart.dart';
import 'widgets/report_type_picker_sheet.dart';

/// Laporan (Reports) screen: report-type + month filter pills, a trend
/// chart, 4 stat cards, and a transaction list. Pendapatan/Pengeluaran
/// render this full body from LaporanDummyData (placeholder numbers, not
/// wired to POS/DB — see that file's doc comment); Laba Rugi/Produk/
/// Customer show a "Segera Hadir" placeholder body instead (selectable in
/// the picker, with no designed report content yet).
///
/// Every branch of the body is a scrollable wrapped in a
/// [RefreshIndicator] with [AlwaysScrollableScrollPhysics], per
/// docs/refresh-pattern.md — including the empty and error states, so
/// swipe-down retry works exactly where it matters most (AGENTS.md:
/// "Errors preserve data and support swipe-down retry").
class LaporanScreen extends ConsumerWidget {
  const LaporanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(laporanProvider);
    final controller = ref.read(laporanProvider.notifier);
    final isIncome = state.reportType == ReportType.pendapatan;
    final accentColor = isIncome ? AppColors.info : AppColors.danger;

    ref.listen(laporanProvider, (previous, next) {
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
              title: const Text('Laporan'),
              trailingIcon: Icons.more_horiz_rounded,
              onTrailingTap: () => _openTypePicker(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterPill(
                      icon: isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      iconColor: accentColor,
                      label: state.reportType.label,
                      onTap: () => _openTypePicker(context, ref),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterPill(
                    label: DateFormat('MMM yyyy', 'id_ID').format(state.selectedMonth),
                    onTap: () => AppNav.showModal(
                      context,
                      isScrollControlled: false,
                      builder: (_) => MonthPickerSheet(current: state.selectedMonth, onSelect: controller.setMonth),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: state.isLoading
                  // Component standards §14: full-screen loading is always
                  // AppColors.brand, even on a screen with its own accent.
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: controller.load,
                      child: _Body(state: state, accentColor: accentColor, onRetry: controller.load),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTypePicker(BuildContext context, WidgetRef ref) {
    final controller = ref.read(laporanProvider.notifier);
    AppNav.showModal(
      context,
      builder: (_) => ReportTypePickerSheet(
        current: ref.read(laporanProvider).reportType,
        onSelect: controller.setReportType,
      ),
    );
  }
}

/// Picks which body to show. Kept as one widget so the three states
/// (error / not-yet-built / real report) all sit under the same
/// RefreshIndicator rather than each screen branch re-deciding.
class _Body extends StatelessWidget {
  final LaporanState state;
  final Color accentColor;
  final Future<void> Function() onRetry;

  const _Body({required this.state, required this.accentColor, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.errorMessage != null) {
      return _CenteredScrollable(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Laporan gagal dimuat',
              subtitle: 'Tarik ke bawah untuk memuat ulang.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 180,
              child: AppButton.secondary(label: 'Coba Lagi', onPressed: onRetry),
            ),
          ],
        ),
      );
    }

    if (!state.reportType.isImplemented) {
      return _CenteredScrollable(
        child: AppEmptyState(
          icon: Icons.construction_rounded,
          title: 'Segera Hadir',
          subtitle: 'Laporan ${state.reportType.label} belum tersedia.',
        ),
      );
    }

    return _ReportBody(state: state, accentColor: accentColor);
  }
}

/// A scrollable that still fills the viewport, so the content centers
/// properly AND RefreshIndicator can detect a pull even though the
/// content is shorter than the screen (docs/refresh-pattern.md step 4).
class _CenteredScrollable extends StatelessWidget {
  final Widget child;
  const _CenteredScrollable({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          SizedBox(height: constraints.maxHeight, child: Center(child: child)),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;

  const _FilterPill({this.icon, this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: (iconColor ?? AppColors.textSecondary).withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final LaporanState state;
  final Color accentColor;
  const _ReportBody({required this.state, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    final isIncome = state.reportType == ReportType.pendapatan;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      children: [
        AppCardShell(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ReportTrendChart(points: data.trend, color: accentColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: isIncome ? Icons.attach_money_rounded : Icons.trending_down_rounded,
                label: isIncome ? 'Pendapatan' : 'Total Pengeluaran',
                value: formatRupiah(data.totalValue),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.receipt_long_rounded,
                label: isIncome ? 'Total Pesanan' : 'Transaksi',
                value: '${data.transactionCount}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                label: isIncome ? 'Rata-rata Nilai Pesanan' : 'Rata-rata per Transaksi',
                value: formatRupiah(data.averagePerTransaction),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_today_rounded,
                label: 'Rata-rata Harian',
                value: formatRupiah(data.averagePerDay),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (data.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: isIncome ? 'Belum ada transaksi' : 'Belum ada pengeluaran',
              subtitle: 'Tidak ada data pada bulan ini.',
            ),
          )
        else
          AppCardShell(
            padding: EdgeInsets.zero,
            child: Column(
              children: data.rows.asMap().entries.map((entry) {
                final row = entry.value;
                final isLast = entry.key == data.rows.length - 1;
                return Container(
                  decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border))),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            if (row.subtitle.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                row.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatRupiah(row.amount),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accentColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
