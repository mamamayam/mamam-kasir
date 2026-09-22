import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_sheet_header.dart';
import '../../../../core/widgets/ios_page_header.dart';

/// STATIC MOCKUP PLACEHOLDER — Laporan.
///
/// This is a visual-only conversion of the supplied `laporan-mockup.html`
/// reference, standing in for the swipe-up menu's "Laporan" tile while
/// the real, DB-wired [LaporanScreen] (lib/features/laporan/...) is
/// broken. It intentionally does NOT touch, import, or port any part of
/// the real Laporan feature (provider/repository/domain) — every number,
/// label and row below is hardcoded demo data taken straight from the
/// mockup, matching its two reference states (Pendapatan / Pengeluaran).
///
/// Do not wire this to Supabase, Riverpod, or any real data source. When
/// the real LaporanScreen is fixed, swap the menu tile back to it (see
/// menu_grid_items.dart) and delete this file — same one-at-a-time
/// placeholder-swap pattern PlaceholderScreen already documents.
///
/// Kept 1:1 with AGENTS.md's visual/component standards: header via
/// [IosPageHeader], cards via [AppCardShell], picker sheet via
/// [AppSheetHeader], and all colors/spacing/radius from AppColors /
/// AppSpacing / AppRadius tokens (no hardcoded hex or magic numbers) —
/// same tokens the mockup's own CSS variables were copied from.
class LaporanMockupPlaceholderScreen extends StatefulWidget {
  const LaporanMockupPlaceholderScreen({super.key});

  @override
  State<LaporanMockupPlaceholderScreen> createState() => _LaporanMockupPlaceholderScreenState();
}

class _LaporanMockupPlaceholderScreenState extends State<LaporanMockupPlaceholderScreen> {
  _MockReportType _current = _MockReportType.pendapatan;

  @override
  Widget build(BuildContext context) {
    final data = _mockData[_current]!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(
              title: const Text('Laporan'),
              trailingIcon: Icons.more_horiz_rounded,
              onTrailingTap: () => _openTypePicker(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterPill(
                      icon: data.icon,
                      iconColor: data.color,
                      label: data.label,
                      onTap: () => _openTypePicker(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const _FilterPill(label: 'Sep 2026', center: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  AppCardShell(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                    child: _MockTrendChart(points: data.chartPoints, color: data.color),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: _StatCard(stat: data.stats[0])),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _StatCard(stat: data.stats[1])),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _StatCard(stat: data.stats[2])),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _StatCard(stat: data.stats[3])),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCardShell(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: data.rows.asMap().entries.map((entry) {
                        final row = entry.value;
                        final isLast = entry.key == data.rows.length - 1;
                        return Container(
                          decoration: BoxDecoration(
                            border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.lg),
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
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      row.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                row.amount,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: data.color),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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

  void _openTypePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MockReportTypePickerSheet(
        current: _current,
        onSelect: (type) => setState(() => _current = type),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;
  final bool center;

  const _FilterPill({this.icon, this.iconColor, required this.label, this.onTap, this.center = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
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

class _StatCard extends StatelessWidget {
  final _MockStat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stat.icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Static placeholder in place of the chart — a plain flat box with an
/// icon and label, fixed height, no CustomPainter/canvas work at all.
/// Kept intentionally dumb (per instruction: "grafiknya dummy aja") so
/// it can never produce a layout/render exception the way a custom
/// painter driven by ambiguous constraints could.
class _MockTrendChart extends StatelessWidget {
  final List<double> points;
  final Color color;
  const _MockTrendChart({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded, size: 32, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Grafik tren',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _MockReportTypePickerSheet extends StatelessWidget {
  final _MockReportType current;
  final ValueChanged<_MockReportType> onSelect;
  const _MockReportTypePickerSheet({required this.current, required this.onSelect});

  static const _icons = {
    _MockReportType.pendapatan: Icons.trending_up_rounded,
    _MockReportType.pengeluaran: Icons.trending_down_rounded,
    _MockReportType.laba: Icons.account_balance_wallet_outlined,
    _MockReportType.produk: Icons.inventory_2_outlined,
    _MockReportType.customer: Icons.people_alt_outlined,
  };

  static const _labels = {
    _MockReportType.pendapatan: 'Pendapatan',
    _MockReportType.pengeluaran: 'Pengeluaran',
    _MockReportType.laba: 'Laba',
    _MockReportType.produk: 'Produk',
    _MockReportType.customer: 'Customer',
  };

  @override
  Widget build(BuildContext context) {
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
              child: AppSheetHeader(title: 'Pilih Jenis Laporan'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _MockReportType.values.map((type) {
                  final isSelected = type == current;
                  final isImplemented = _mockData.containsKey(type);
                  return InkWell(
                    onTap: () {
                      if (!isImplemented) return;
                      onSelect(type);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.info.withValues(alpha: 0.12) : AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_icons[type], size: 19, color: isSelected ? AppColors.info : AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              _labels[type]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          if (!isImplemented)
                            const Padding(
                              padding: EdgeInsets.only(right: AppSpacing.sm),
                              child: Text(
                                'SEGERA',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.25, color: AppColors.textMuted),
                              ),
                            ),
                          if (isSelected) const Icon(Icons.check_rounded, size: 18, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

enum _MockReportType { pendapatan, pengeluaran, laba, produk, customer }

class _MockStat {
  final IconData icon;
  final String label;
  final String value;
  const _MockStat({required this.icon, required this.label, required this.value});
}

class _MockRow {
  final String title;
  final String subtitle;
  final String amount;
  const _MockRow({required this.title, required this.subtitle, required this.amount});
}

class _MockReportData {
  final String label;
  final IconData icon;
  final Color color;
  final List<double> chartPoints;
  final List<_MockStat> stats;
  final List<_MockRow> rows;
  const _MockReportData({
    required this.label,
    required this.icon,
    required this.color,
    required this.chartPoints,
    required this.stats,
    required this.rows,
  });
}

/// Demo data lifted verbatim from laporan-mockup.html — only the two
/// fully-designed states (Pendapatan / Pengeluaran) have data; Laba,
/// Produk, Customer stay picker-only entries marked "SEGERA", exactly
/// as the mockup describes them.
final Map<_MockReportType, _MockReportData> _mockData = {
  _MockReportType.pendapatan: const _MockReportData(
    label: 'Pendapatan',
    icon: Icons.trending_up_rounded,
    color: AppColors.info,
    chartPoints: [0, 20, 0, 0, 0, 60, 0, 0, 20, 0, 40],
    stats: [
      _MockStat(icon: Icons.attach_money_rounded, label: 'Pendapatan', value: 'Rp 140.140'),
      _MockStat(icon: Icons.receipt_long_rounded, label: 'Total Pesanan', value: '5'),
      _MockStat(icon: Icons.trending_up_rounded, label: 'Rata-rata Nilai Pesanan', value: 'Rp 28.028'),
      _MockStat(icon: Icons.calendar_today_rounded, label: 'Rata-rata Harian', value: 'Rp 12.740'),
    ],
    rows: [
      _MockRow(title: 'Pelanggan', subtitle: 'Mamam Ayam - 11 Sep, 11:50', amount: 'Rp 42.180'),
      _MockRow(title: 'Pelanggan', subtitle: 'Mamam Ayam - 09 Sep, 15:06', amount: 'Rp 19.980'),
      _MockRow(title: 'Pelanggan', subtitle: 'Mamam Ayam - 06 Sep, 07:42', amount: 'Rp 19.980'),
      _MockRow(title: 'Pelanggan', subtitle: 'Mamam Ayam - 06 Sep, 07:39', amount: 'Rp 38.000'),
      _MockRow(title: 'Pelanggan', subtitle: 'Mamam Ayam - 02 Sep, 14:08', amount: 'Rp 20.000'),
    ],
  ),
  _MockReportType.pengeluaran: const _MockReportData(
    label: 'Pengeluaran',
    icon: Icons.trending_down_rounded,
    color: AppColors.danger,
    chartPoints: [0, 0, 0, 30, 0, 0, 0, 0, 0, 0, 0],
    stats: [
      _MockStat(icon: Icons.trending_down_rounded, label: 'Total Pengeluaran', value: 'Rp 25.000'),
      _MockStat(icon: Icons.receipt_long_rounded, label: 'Transaksi', value: '1'),
      _MockStat(icon: Icons.trending_up_rounded, label: 'Rata-rata per Transaksi', value: 'Rp 25.000'),
      _MockStat(icon: Icons.calendar_today_rounded, label: 'Rata-rata Harian', value: 'Rp 2.273'),
    ],
    rows: [
      _MockRow(title: 'Belanja', subtitle: 'Mamam Ayam - 04 Sep, 17:55', amount: 'Rp 25.000'),
    ],
  ),
};
