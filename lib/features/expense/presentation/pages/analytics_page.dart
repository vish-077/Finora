import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';
import 'package:finora/features/expense/presentation/viewmodels/analytics_controller.dart';
import 'package:finora/features/expense/presentation/widgets/bar_chart_widget.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/features/expense/presentation/widgets/pie_chart_widget.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(analyticsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FinoraEmptyState(
          icon: const Icon(Icons.error_outline, size: 56),
          title: 'Could not load analytics',
          subtitle: e is Failure ? e.message : '$e',
          action: FilledButton(
            onPressed: () =>
                ref.read(analyticsControllerProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () =>
              ref.read(analyticsControllerProvider.notifier).refresh(),
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              AppSpacing.vMd,
              _PeriodSelector(
                selected: summary.period,
                onChanged: (p) => ref
                    .read(analyticsControllerProvider.notifier)
                    .setPeriod(p),
              ),
              AppSpacing.vLg,
              _SummaryCards(summary: summary),
              AppSpacing.vLg,
              _SavingsIndicator(summary: summary),
              AppSpacing.vXl,
              _SectionTitle(title: 'Income vs Expense'),
              AppSpacing.vMd,
              FinoraBarChart(data: summary.barData),
              AppSpacing.vXl,
              _SectionTitle(title: 'Spending by Category'),
              AppSpacing.vMd,
              _PieChartSection(summary: summary),
              AppSpacing.vXl,
              _SectionTitle(title: 'Top Categories'),
              AppSpacing.vMd,
              _TopCategoriesList(categories: summary.topCategories),
              AppSpacing.vXxl,
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final AnalyticsPeriod selected;
  final ValueChanged<AnalyticsPeriod> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<AnalyticsPeriod>(
        segments: [
          for (final p in AnalyticsPeriod.values)
            ButtonSegment(value: p, label: Text(p.label)),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Income',
              amount: summary.totalIncome,
              icon: Icons.arrow_downward,
              color: AppColors.income,
              gradient: AppColors.incomeGradient,
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: _SummaryCard(
              label: 'Expense',
              amount: summary.totalExpense,
              icon: Icons.arrow_upward,
              color: AppColors.expense,
              gradient: AppColors.expenseGradient,
            ),
          ),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 18),
                AppSpacing.hXs,
                Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            AppSpacing.vSm,
            Text(
              amount.formatCurrency(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
}

class _SavingsIndicator extends StatelessWidget {
  const _SavingsIndicator({required this.summary});
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.savings >= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: isPositive ? AppColors.income : AppColors.expense,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.income : AppColors.expense)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isPositive ? Icons.savings_outlined : Icons.warning_amber_rounded,
              color: isPositive ? AppColors.income : AppColors.expense,
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? 'Savings' : 'Over Budget',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  summary.savings.abs().formatCurrency(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            isPositive ? AppColors.income : AppColors.expense,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isPositive ? AppColors.income : AppColors.expense)
                  .withValues(alpha: 0.15),
              borderRadius: AppRadius.pillRadius,
            ),
            child: Text(
              '${summary.savingsRate.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isPositive ? AppColors.income : AppColors.expense,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieChartSection extends StatelessWidget {
  const _PieChartSection({required this.summary});
  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.pieData.isEmpty) {
      return const FinoraEmptyState(
        icon: Icon(Icons.pie_chart_outline, size: 48),
        title: 'No expense data',
        subtitle: 'Add some expenses to see the breakdown',
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinoraPieChart(
          data: summary.pieData,
          size: 160,
          strokeWidth: 24,
          centerLabel: 'Total',
          centerAmount: summary.totalExpense.formatAmount(),
        ),
        AppSpacing.hLg,
        Expanded(
          child: PieChartLegend(data: summary.pieData.take(6).toList()),
        ),
      ],
    );
  }
}

class _TopCategoriesList extends StatelessWidget {
  const _TopCategoriesList({required this.categories});
  final List<PieChartEntry> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final max = categories.first.amount;

    return Column(
      children: [
        for (final cat in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CategoryVisuals.color(cat.color)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: CategoryVisuals.color(cat.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              cat.categoryName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            cat.amount.formatCurrency(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      AppSpacing.vXs,
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max > 0
                              ? (cat.amount / max).clamp(0.0, 1.0)
                              : 0,
                          minHeight: 6,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                            CategoryVisuals.color(cat.color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );
}
