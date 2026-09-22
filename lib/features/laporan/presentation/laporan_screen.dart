import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/laporan_provider.dart';
import '../domain/laporan_models.dart';
import 'widgets/month_picker_sheet.dart';
import 'widgets/report_trend_chart.dart';
import 'widgets/report_type_picker_sheet.dart';

/// Laporan (Reports) screen, ported 1:1 from the approved HTML mockup:
/// report-type + month filter pills, a trend chart, 4 stat cards, and a
/// transaction list. Pendapatan/Pengeluaran are fully wired to real
/// data; Laba/Produk/Customer show a "Segera Hadir" placeholder body
/// (selectable in the picker, matching the mockup, but with no designed
/// report content yet).
class LaporanScreen extends ConsumerWidget {
  const LaporanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(laporanProvider);
    final controller = ref.read(laporanProvider.notifier);
    final isIncome = state.reportType == ReportType.pendapatan;
    final accentColor = isIncome ? AppColors.info : AppColors.danger;

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
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : state.errorMessage != null
                      ? _ReportErrorBody(
                          message: state.errorMessage!,
                          onRetry: controller.load,
                        )
                      : !state.reportType.isImplemented
                          ? const _ComingSoonBody()
                          : _ReportBody(state: state, accentColor: accentColor),
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
      isScrollControlled: false,
      builder: (_) => ReportTypePickerSheet(
        current: ref.read(laporanProvider).reportType,
        onSelect: controller.setReportType,
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
            const SizedBox(width: 4),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl)),
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
            child: Center(
              child: Text(
                isIncome ? 'Belum ada transaksi bulan ini.' : 'Belum ada pengeluaran bulan ini.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              children: data.rows.asMap().entries.map((entry) {
                final row = entry.value;
                final isLast = entry.key == data.rows.length - 1;
                return Container(
                  decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border))),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(row.subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ReportErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ReportErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            const Text('Gagal Memuat Laporan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          const Text('Segera Hadir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Laporan ini belum tersedia.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
