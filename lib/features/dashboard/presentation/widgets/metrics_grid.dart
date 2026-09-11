import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/dashboard_models.dart';

/// 2x2 metrics grid matching the supplied mockup exactly.
///
/// NOTE: only `totalPengeluaran` and `labaKotor` are PRD-defined dashboard
/// metrics (docs/01_PRD.md). `totalPesanan` and `rataRata` are kept here
/// per explicit instruction to match the mockup during this shell-first
/// pass — see [[mamam-kasir-flutter]] notes for the decision to defer
/// metric correctness to the dashboard feature phase.
class MetricsGrid extends StatelessWidget {
  final DashboardMetrics metrics;
  const MetricsGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.35,
      children: [
        _MetricCard(
          icon: Icons.trending_down_rounded,
          iconColor: AppColors.danger,
          label: 'TOTAL PENGELUARAN',
          value: formatRupiah(metrics.totalPengeluaran),
        ),
        _MetricCard(
          icon: Icons.attach_money_rounded,
          iconColor: AppColors.brand,
          label: 'LABA KOTOR',
          value: formatRupiah(metrics.labaKotor),
        ),
        _MetricCard(
          icon: Icons.receipt_rounded,
          iconColor: AppColors.info,
          label: 'TOTAL PESANAN',
          value: '${metrics.totalPesanan} Pesanan',
        ),
        _MetricCard(
          icon: Icons.show_chart_rounded,
          iconColor: const Color(0xFF8B7CC7),
          label: 'RATA-RATA',
          value: formatRupiah(metrics.rataRata),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricCard({required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
