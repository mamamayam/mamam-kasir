import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// STATIC MOCKUP PLACEHOLDER — Laporan.
///
/// Visual-only conversion of `laporan-mockup.html`, standing in for the
/// swipe-up menu's "Laporan" tile while the real, DB-wired LaporanScreen
/// (lib/features/laporan/...) is still blank/broken. Dummy data only —
/// deliberately NOT wired to Riverpod, Supabase, or any real data
/// source. Swap the menu tile back to the real LaporanScreen once it's
/// built out, then delete this file.
///
/// Kept simple on purpose: does not follow AGENTS.md component
/// standards (no IosPageHeader/AppCardShell) — just needs to render and
/// be tappable for now.
class LaporanMockupPlaceholderScreen extends StatefulWidget {
  const LaporanMockupPlaceholderScreen({super.key});

  @override
  State<LaporanMockupPlaceholderScreen> createState() => _LaporanMockupPlaceholderScreenState();
}

// ---------------------------------------------------------------------------
// Dummy data — mirrors the reference HTML mockup exactly.
// ---------------------------------------------------------------------------
class _LaporanRow {
  final String title;
  final String sub;
  final String amount;
  const _LaporanRow({required this.title, required this.sub, required this.amount});
}

class _LaporanStat {
  final IconData icon;
  final String label;
  final String value;
  const _LaporanStat({required this.icon, required this.label, required this.value});
}

class _ReportType {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final List<double>? chartPoints; // null => not implemented yet
  final List<_LaporanStat> stats;
  final String amountKind; // 'income' | 'expense'
  final List<_LaporanRow> rows;

  const _ReportType({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.chartPoints,
    required this.stats,
    required this.amountKind,
    required this.rows,
  });
}

final Map<String, _ReportType> _kDummyReports = {
  'pendapatan': _ReportType(
    key: 'pendapatan',
    label: 'Pendapatan',
    icon: Icons.trending_up_rounded,
    color: AppColors.info,
    chartPoints: const [0, 20, 0, 0, 0, 60, 0, 0, 20, 0, 40],
    stats: const [
      _LaporanStat(icon: Icons.attach_money_rounded, label: 'Pendapatan', value: 'Rp 140.140'),
      _LaporanStat(icon: Icons.receipt_long_rounded, label: 'Total Pesanan', value: '5'),
      _LaporanStat(icon: Icons.trending_up_rounded, label: 'Rata-rata Nilai Pesanan', value: 'Rp 28.028'),
      _LaporanStat(icon: Icons.calendar_month_rounded, label: 'Rata-rata Harian', value: 'Rp 12.740'),
    ],
    amountKind: 'income',
    rows: const [
      _LaporanRow(title: 'Pelanggan', sub: 'Mamam Ayam - 11 Sep, 11:50', amount: 'Rp 42.180'),
      _LaporanRow(title: 'Pelanggan', sub: 'Mamam Ayam - 09 Sep, 15:06', amount: 'Rp 19.980'),
      _LaporanRow(title: 'Pelanggan', sub: 'Mamam Ayam - 06 Sep, 07:42', amount: 'Rp 19.980'),
      _LaporanRow(title: 'Pelanggan', sub: 'Mamam Ayam - 06 Sep, 07:39', amount: 'Rp 38.000'),
      _LaporanRow(title: 'Pelanggan', sub: 'Mamam Ayam - 02 Sep, 14:08', amount: 'Rp 20.000'),
    ],
  ),
  'pengeluaran': _ReportType(
    key: 'pengeluaran',
    label: 'Pengeluaran',
    icon: Icons.trending_down_rounded,
    color: AppColors.danger,
    chartPoints: const [0, 0, 0, 30, 0, 0, 0, 0, 0, 0, 0],
    stats: const [
      _LaporanStat(icon: Icons.trending_down_rounded, label: 'Total Pengeluaran', value: 'Rp 25.000'),
      _LaporanStat(icon: Icons.receipt_long_rounded, label: 'Transaksi', value: '1'),
      _LaporanStat(icon: Icons.trending_up_rounded, label: 'Rata-rata per Transaksi', value: 'Rp 25.000'),
      _LaporanStat(icon: Icons.calendar_month_rounded, label: 'Rata-rata Harian', value: 'Rp 2.273'),
    ],
    amountKind: 'expense',
    rows: const [
      _LaporanRow(title: 'Belanja', sub: 'Mamam Ayam - 04 Sep, 17:55', amount: 'Rp 25.000'),
    ],
  ),
  'laba': _ReportType(
    key: 'laba',
    label: 'Laba',
    icon: Icons.account_balance_wallet_rounded,
    color: AppColors.brand,
    chartPoints: null,
    stats: const [],
    amountKind: 'income',
    rows: const [],
  ),
  'produk': _ReportType(
    key: 'produk',
    label: 'Produk',
    icon: Icons.inventory_2_rounded,
    color: AppColors.brand,
    chartPoints: null,
    stats: const [],
    amountKind: 'income',
    rows: const [],
  ),
  'customer': _ReportType(
    key: 'customer',
    label: 'Customer',
    icon: Icons.people_alt_rounded,
    color: AppColors.brand,
    chartPoints: null,
    stats: const [],
    amountKind: 'income',
    rows: const [],
  ),
};

class _LaporanMockupPlaceholderScreenState extends State<LaporanMockupPlaceholderScreen> {
  String _activeKey = 'pendapatan';
  DateTime _month = DateTime(2026, 9);

  _ReportType get _active => _kDummyReports[_activeKey]!;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String get _monthLabel => '${_monthNames[_month.month - 1]} ${_month.year}';

  void _openReportPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ReportPickerSheet(
        activeKey: _activeKey,
        onSelect: (key) {
          final target = _kDummyReports[key]!;
          if (target.chartPoints == null) {
            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Laporan ${target.label} belum tersedia')),
            );
            return;
          }
          setState(() => _activeKey = key);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih Bulan',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: 'Laporan',
              onBack: () => Navigator.of(context).maybePop(),
              onTrailing: _openReportPicker,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterRow(
                      active: _active,
                      monthLabel: _monthLabel,
                      onTapReportType: _openReportPicker,
                      onTapMonth: _pickMonth,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ChartCard(report: _active),
                    const SizedBox(height: AppSpacing.md),
                    _StatGrid(stats: _active.stats),
                    const SizedBox(height: AppSpacing.sm),
                    _TransactionListCard(report: _active),
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

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onTrailing;

  const _Header({required this.title, required this.onBack, required this.onTrailing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _CircleButton(icon: Icons.more_horiz_rounded, onTap: onTrailing),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row: report-type pill + month pill
// ---------------------------------------------------------------------------
class _FilterRow extends StatelessWidget {
  final _ReportType active;
  final String monthLabel;
  final VoidCallback onTapReportType;
  final VoidCallback onTapMonth;

  const _FilterRow({
    required this.active,
    required this.monthLabel,
    required this.onTapReportType,
    required this.onTapMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _PillSelect(
              onTap: onTapReportType,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: active.color.withValues(alpha: 0.12)),
                    child: Icon(active.icon, size: 15, color: active.color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      active.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _PillSelect(
              onTap: onTapMonth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    monthLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillSelect extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PillSelect({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart card
// ---------------------------------------------------------------------------
class _ChartCard extends StatelessWidget {
  final _ReportType report;

  const _ChartCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final points = report.chartPoints;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: SizedBox(
        height: 220,
        child: points == null
            ? const Center(
                child: Text('Belum ada data', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              )
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 60,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: 20,
                        getTitlesWidget: (value, meta) => Text(
                          value == 0 ? 'Rp 0' : 'Rp ${value.toInt()}.0K',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i])],
                      isCurved: false,
                      color: report.color,
                      barWidth: 2.6,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: report.color.withValues(alpha: 0.08)),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: true),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat cards — 2x2 grid
// ---------------------------------------------------------------------------
class _StatGrid extends StatelessWidget {
  final List<_LaporanStat> stats;

  const _StatGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.7,
        children: stats.map((s) => _StatCard(stat: s)).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _LaporanStat stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(stat.icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction list card
// ---------------------------------------------------------------------------
class _TransactionListCard extends StatelessWidget {
  final _ReportType report;

  const _TransactionListCard({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.rows.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        alignment: Alignment.center,
        child: const Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    final amountColor = report.amountKind == 'income' ? AppColors.info : AppColors.danger;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < report.rows.length; i++)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                border: i == report.rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.rows[i].title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(report.rows[i].sub, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Text(
                    report.rows[i].amount,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: amountColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Pilih Jenis Laporan" bottom sheet
// ---------------------------------------------------------------------------
class _ReportPickerSheet extends StatelessWidget {
  final String activeKey;
  final ValueChanged<String> onSelect;

  const _ReportPickerSheet({required this.activeKey, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = _kDummyReports.values.toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih Jenis Laporan',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  Material(
                    color: AppColors.background,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final opt = options[i];
                  final isActive = opt.key == activeKey;
                  return InkWell(
                    onTap: () => onSelect(opt.key),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? AppColors.info.withValues(alpha: 0.12) : AppColors.background,
                            ),
                            child: Icon(opt.icon, size: 19, color: isActive ? AppColors.info : AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              opt.label,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                          if (isActive) const Icon(Icons.check_rounded, size: 18, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
