import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/ai/domain/entities/ai_entities.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_dashboard_controller.dart';

class AiDashboardCard extends ConsumerWidget {
  const AiDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiDashboardControllerProvider);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('Error loading AI insights: $e'),
        ),
        data: (data) {
          if (data.health == null) return const SizedBox.shrink();
          return _buildContent(context, ref, data);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AiDashboardState data,
  ) {
    final theme = Theme.of(context);
    final health = data.health!;
    final scoreColor = _scoreColor(health.score);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 17),
              ),
              AppSpacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Financial Health',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _statusHeadline(health),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Recalculate',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => ref
                    .read(aiDashboardControllerProvider.notifier)
                    .refresh(),
              ),
            ],
          ),
          AppSpacing.vMd,

          // ── Score ring + the factors that actually contributed ──
          if (health.hasNoData)
            _NoDataNotice(theme: theme)
          else
            Row(
              children: [
                _ScoreRing(score: health.score, color: scoreColor),
                AppSpacing.hLg,
                Expanded(
                  child: Column(
                    children: [
                      for (final factor in health.factors.take(3)) ...[
                        _MetricBar(
                          label: factor.label,
                          value: factor.percent,
                          caption: factor.detail,
                          color: _factorColor(factor.value),
                          icon: _factorIcon(factor.label),
                        ),
                        if (factor != health.factors.take(3).last)
                          AppSpacing.vSm,
                      ],
                    ],
                  ),
                ),
              ],
            ),

          // Say plainly when the score is based on partial data, instead of
          // implying a missing factor was perfect.
          if (!health.hasNoData && health.dataCoverage < 0.99) ...[
            AppSpacing.vSm,
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 13, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    health.budgetAdherence == null
                        ? 'Set a monthly budget to score budget adherence too.'
                        : 'Based on the data recorded so far this month.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],

          AppSpacing.vMd,
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          AppSpacing.vMd,

          // ── Insights ──
          if (data.insights.isEmpty)
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    'Keep logging transactions — insights appear once there is '
                    'enough history to spot a pattern.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'What stands out',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (data.insights.length > 2)
                  Text(
                    '${data.insights.length} insights',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            AppSpacing.vSm,
            // Two is enough on a dashboard; the assistant page has the rest.
            for (final insight in data.insights.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _InsightRow(insight: insight),
              ),
          ],

          AppSpacing.vSm,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.aiAssistant),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Ask AI'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(Routes.reports),
                  icon: const Icon(Icons.insights_rounded, size: 18),
                  label: const Text('Reports'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _factorColor(double value) {
    if (value >= 0.75) return AppColors.income;
    if (value >= 0.5) return AppColors.primary;
    if (value >= 0.25) return AppColors.warning;
    return AppColors.error;
  }

  static IconData _factorIcon(String label) {
    switch (label) {
      case 'Savings rate':
        return Icons.savings_rounded;
      case 'Budget adherence':
        return Icons.track_changes_rounded;
      case 'Spending vs income':
        return Icons.compare_arrows_rounded;
      case 'Tracking consistency':
        return Icons.event_available_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  static Color _scoreColor(int score) {
    if (score >= 80) return AppColors.income;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  static String _statusHeadline(FinancialHealth health) {
    switch (health.status) {
      case HealthStatus.excellent:
        return 'Excellent — you are well ahead';
      case HealthStatus.good:
        return 'Good — steady and on track';
      case HealthStatus.average:
        return 'Average — room to tighten up';
      case HealthStatus.poor:
        return 'Needs attention — spending is high';
    }
  }
}

/// Circular score gauge with the number called out in the middle.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(92),
            painter: _RingPainter(
              progress: (score / 100).clamp(0.0, 1.0),
              color: color,
              track: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                '/ 100',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;

    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.55), color],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(rect);

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2, // start at 12 o'clock
      math.pi * 2 * progress,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// A labelled 0–100 gauge with the figure spelled out beneath it.
class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final String caption;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});
  final FinancialInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(insight.severity);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_severityIcon(insight.severity), color: color, size: 18),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(insight.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (insight.actionRoute != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              onPressed: () => context.push(insight.actionRoute!),
            ),
        ],
      ),
    );
  }

  static IconData _severityIcon(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return Icons.info_outline;
      case InsightSeverity.warning:
        return Icons.warning_amber_rounded;
      case InsightSeverity.success:
        return Icons.check_circle_outline;
    }
  }

  static Color _severityColor(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.info:
        return AppColors.primary;
      case InsightSeverity.warning:
        return AppColors.warning;
      case InsightSeverity.success:
        return AppColors.income;
    }
  }
}

/// Shown when no factor could be measured. Better than a fabricated score.
class _NoDataNotice extends StatelessWidget {
  const _NoDataNotice({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.query_stats_rounded,
                color: theme.colorScheme.onSurfaceVariant),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not enough data yet',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Record some income and expenses this month and a real '
                    'health score will appear here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
