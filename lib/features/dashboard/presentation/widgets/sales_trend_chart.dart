import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/dashboard_models.dart';

/// Tappable sales trend line chart. Horizontally scrollable, weekday dots
/// in a muted tone and weekend dots in brand orange (matching the mockup's
/// weekday/weekend legend), tap a dot to see that day's figure.
class SalesTrendChart extends StatelessWidget {
  final List<SalesTrendPoint> points;
  final void Function(SalesTrendPoint point) onPointTap;

  const SalesTrendChart({super.key, required this.points, required this.onPointTap});

  @override
  Widget build(BuildContext context) {
    final firstDate = points.first.date;
    final lastDate = points.last.date;
    final rangeLabel = '${DateFormat('d MMM', 'id_ID').format(firstDate)} - ${DateFormat('d MMM', 'id_ID').format(lastDate)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tren Penjualan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(rangeLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: const [
              _LegendDot(color: Color(0xFFB0743E), label: 'Hari Biasa'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.brand, label: 'Weekend'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 130,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: (points.length * 30).toDouble() + 15,
                child: GestureDetector(
                  onTapUp: (details) => _handleTap(details.localPosition),
                  child: CustomPaint(
                    painter: _TrendPainter(points: points),
                    size: Size((points.length * 30).toDouble() + 15, 130),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '*Geser grafik & ketuk titik tanggal untuk detail omzet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _handleTap(Offset localPosition) {
    const maxVal = 3000000;
    const chartTop = 10.0;
    const chartBottom = 90.0;

    for (var i = 0; i < points.length; i++) {
      final cx = i * 30 + 15;
      final cy = chartBottom - (points[i].value / maxVal * (chartBottom - chartTop));
      final dx = localPosition.dx - cx;
      final dy = localPosition.dy - cy;
      if (dx * dx + dy * dy <= 14 * 14) {
        onPointTap(points[i]);
        return;
      }
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<SalesTrendPoint> points;
  static const int maxVal = 3000000;
  static const double chartTop = 10.0;
  static const double chartBottom = 90.0;

  _TrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final y in [20.0, 50.0, 80.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final cx = i * 30 + 15.0;
      final cy = chartBottom - (points[i].value / maxVal * (chartBottom - chartTop));
      if (i == 0) {
        path.moveTo(cx, cy);
      } else {
        path.lineTo(cx, cy);
      }
    }
    canvas.drawPath(path, linePaint);

    final labelPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = i * 30 + 15.0;
      final cy = chartBottom - (p.value / maxVal * (chartBottom - chartTop));
      final dotColor = p.isWeekend ? AppColors.brand : const Color(0xFFB0743E);

      canvas.drawCircle(Offset(cx, cy), 4.5, Paint()..color = dotColor);
      canvas.drawCircle(
        Offset(cx, cy),
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      labelPainter.text = TextSpan(
        text: DateFormat('d/M', 'id_ID').format(p.date),
        style: TextStyle(
          fontSize: 9,
          fontWeight: p.isWeekend ? FontWeight.w700 : FontWeight.w500,
          color: p.isWeekend ? AppColors.textSecondary : AppColors.textMuted,
        ),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, chartBottom + 18));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.points != points;
}
