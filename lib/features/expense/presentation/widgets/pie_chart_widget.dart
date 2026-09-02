import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';

/// A custom pie chart widget drawn with Canvas.
/// No external chart library dependency.
class FinoraPieChart extends StatelessWidget {
  const FinoraPieChart({
    super.key,
    required this.data,
    this.size = 200,
    this.strokeWidth = 28,
    this.centerLabel,
    this.centerAmount,
  });

  final List<PieChartEntry> data;
  final double size;
  final double strokeWidth;
  final String? centerLabel;
  final String? centerAmount;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'No data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PieChartPainter(
          entries: data,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerLabel != null)
                Text(
                  centerLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              if (centerAmount != null)
                Text(
                  centerAmount!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({
    required this.entries,
    required this.strokeWidth,
  });

  final List<PieChartEntry> entries;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    var currentAngle = startAngle;

    final totalAmount = entries.fold(0.0, (sum, e) => sum + e.amount);
    if (totalAmount <= 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final entry in entries) {
      final sweepAngle = (entry.amount / totalAmount) * 2 * math.pi;
      paint.color = CategoryVisuals.color(entry.color);
      canvas.drawArc(rect, currentAngle, sweepAngle - 0.02, false, paint);
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) =>
      entries != old.entries || strokeWidth != old.strokeWidth;
}

/// Legend for the pie chart.
class PieChartLegend extends StatelessWidget {
  const PieChartLegend({
    super.key,
    required this.data,
    this.formatAmount,
  });

  final List<PieChartEntry> data;
  final String Function(double)? formatAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: CategoryVisuals.color(entry.color),
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    entry.categoryName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
