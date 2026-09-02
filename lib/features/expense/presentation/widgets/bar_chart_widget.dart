import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';

/// A custom bar chart widget drawn with Canvas.
/// No external chart library dependency.
class FinoraBarChart extends StatelessWidget {
  const FinoraBarChart({
    super.key,
    required this.data,
    this.height = 200,
    this.showIncome = true,
    this.showExpense = true,
  });

  final List<BarChartEntry> data;
  final double height;
  final bool showIncome;
  final bool showExpense;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
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

    return Column(
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size(double.infinity, height),
            painter: _BarChartPainter(
              entries: data,
              incomeColor: AppColors.income,
              expenseColor: AppColors.expense,
              gridColor: Theme.of(context).colorScheme.outlineVariant,
              labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              showIncome: showIncome,
              showExpense: showExpense,
            ),
          ),
        ),
        AppSpacing.vSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIncome) ...[
              _LegendDot(color: AppColors.income, label: 'Income'),
              AppSpacing.hBase,
            ],
            if (showExpense)
              _LegendDot(color: AppColors.expense, label: 'Expense'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          AppSpacing.hXs,
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.entries,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.labelColor,
    required this.showIncome,
    required this.showExpense,
  });

  final List<BarChartEntry> entries;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final Color labelColor;
  final bool showIncome;
  final bool showExpense;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    const bottomMargin = 24.0;
    const topMargin = 8.0;
    final chartHeight = size.height - bottomMargin - topMargin;
    final barGroupWidth = size.width / entries.length;
    final barsPerGroup = (showIncome ? 1 : 0) + (showExpense ? 1 : 0);
    final barWidth = math.min(
      (barGroupWidth * 0.7) / math.max(barsPerGroup, 1),
      24.0,
    );

    // Find max value for scaling
    var maxVal = 0.0;
    for (final e in entries) {
      if (showIncome && e.income > maxVal) maxVal = e.income;
      if (showExpense && e.expense > maxVal) maxVal = e.expense;
    }
    if (maxVal <= 0) maxVal = 1;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = topMargin + chartHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw bars
    final incomePaint = Paint()..color = incomeColor;
    final expensePaint = Paint()..color = expenseColor;
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final groupCenter = barGroupWidth * i + barGroupWidth / 2;
      var barOffset = -((barsPerGroup - 1) * barWidth + (barsPerGroup - 1) * 2) / 2;

      if (showIncome) {
        final h = (entry.income / maxVal) * chartHeight;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            groupCenter + barOffset,
            topMargin + chartHeight - h,
            barWidth,
            math.max(h, 1),
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, incomePaint);
        barOffset += barWidth + 2;
      }

      if (showExpense) {
        final h = (entry.expense / maxVal) * chartHeight;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            groupCenter + barOffset,
            topMargin + chartHeight - h,
            barWidth,
            math.max(h, 1),
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, expensePaint);
      }

      // Draw label
      final tp = TextPainter(
        text: TextSpan(text: entry.label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          groupCenter - tp.width / 2,
          size.height - bottomMargin + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      entries != old.entries ||
      showIncome != old.showIncome ||
      showExpense != old.showExpense;
}
