import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/laporan_models.dart';

/// Line + area-fill trend chart, ported from the HTML mockup's SVG
/// (`series-line` / `series-area` paths). Color is passed in so the same
/// chart shape serves both Pendapatan (info blue) and Pengeluaran
/// (danger red), matching the mockup's per-report-type accent.
class ReportTrendChart extends StatelessWidget {
  final List<ReportTrendPoint> points;
  final Color color;

  const ReportTrendChart({super.key, required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = points.map((p) => p.value).fold<int>(0, (a, b) => a > b ? a : b);
    // Round the axis ceiling up to a "nice" step so gridline labels read
    // like the mockup's "Rp 60.0K" style rather than an arbitrary max.
    final axisMax = _niceCeiling(maxValue);

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _YAxisLabels(axisMax: axisMax),
          const SizedBox(width: 8),
          Expanded(
            child: CustomPaint(
              painter: _ReportChartPainter(points: points, color: color, axisMax: axisMax),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  int _niceCeiling(int value) {
    if (value <= 0) return 10000;
    final magnitude = value < 100000 ? 10000 : 20000;
    return ((value / magnitude).ceil() * magnitude).clamp(magnitude, 1 << 30);
  }
}

class _YAxisLabels extends StatelessWidget {
  final int axisMax;
  const _YAxisLabels({required this.axisMax});

  @override
  Widget build(BuildContext context) {
    final steps = 4;
    return SizedBox(
      width: 52,
      height: 190,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(steps + 1, (i) {
          final value = axisMax - (axisMax / steps * i);
          return Text(
            _formatShort(value.round()),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          );
        }),
      ),
    );
  }

  String _formatShort(int value) {
    if (value == 0) return 'Rp 0';
    if (value >= 1000) return 'Rp ${(value / 1000).toStringAsFixed(1)}K';
    return 'Rp $value';
  }
}

class _ReportChartPainter extends CustomPainter {
  final List<ReportTrendPoint> points;
  final Color color;
  final int axisMax;

  _ReportChartPainter({required this.points, required this.color, required this.axisMax});

  @override
  void paint(Canvas canvas, Size size) {
    const chartTop = 10.0;
    final chartBottom = size.height - 30;
    final stepX = points.length > 1 ? size.width / (points.length - 1) : size.width;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartTop + (chartBottom - chartTop) / 4 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointAt(int i) {
      final x = stepX * i;
      // NOTE: keep every operand here a `double`. Dart only special-cases
      // `clamp()` to return the receiver's type when receiver AND both
      // bounds are all int or all double — `someDouble.clamp(0, 1)` is
      // statically `num`, which makes `y` a `num` and fails to compile at
      // `Offset(x, y)`. That is exactly what broke this screen before.
      final ratio = axisMax <= 0 ? 0.0 : (points[i].value / axisMax).clamp(0.0, 1.0);
      final y = chartBottom - ratio * (chartBottom - chartTop);
      return Offset(x, y);
    }

    final linePath = Path();
    final areaPath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
        areaPath.moveTo(p.dx, chartBottom);
        areaPath.lineTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
        areaPath.lineTo(p.dx, p.dy);
      }
    }
    areaPath.lineTo(pointAt(points.length - 1).dx, chartBottom);
    areaPath.close();

    canvas.drawPath(areaPath, Paint()..color = color.withValues(alpha: 0.08));
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // X-axis day labels — sparse (every ~1/5th) to avoid crowding, same
    // spirit as the mockup's "1 3 5 7 9 11" tick marks.
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelInterval = (points.length / 6).ceil().clamp(1, points.length);
    for (var i = 0; i < points.length; i += labelInterval) {
      final p = pointAt(i);
      labelPainter.text = TextSpan(
        text: '${points[i].day}',
        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(p.dx - labelPainter.width / 2, chartBottom + 12));
    }
  }

  @override
  bool shouldRepaint(covariant _ReportChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
