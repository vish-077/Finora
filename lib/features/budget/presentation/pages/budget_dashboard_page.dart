import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_list_controller.dart';
import 'package:finora/features/budget/presentation/widgets/budget_editor_sheet.dart';
import 'package:finora/features/budget/presentation/widgets/category_budget_card.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class BudgetDashboardPage extends ConsumerWidget {
  const BudgetDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBudgets = ref.watch(budgetListControllerProvider);
    final controller = ref.watch(budgetListControllerProvider.notifier);
    final currentDate = controller.currentDate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => BudgetEditorSheet.show(
              context,
              month: currentDate.month,
              year: currentDate.year,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthSelector(
            currentDate: currentDate,
            onChanged: (d) => controller.changeMonth(d.month, d.year),
          ),
          Expanded(
            child: asyncBudgets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => FinoraEmptyState(
                icon: const Icon(Icons.error_outline, size: 56),
                title: 'Could not load budgets',
                subtitle: e is Failure ? e.message : '$e',
                action: FilledButton(
                  onPressed: () => controller.refresh(),
                  child: const Text('Retry'),
                ),
              ),
              data: (progressList) {
                if (progressList.isEmpty) {
                  return FinoraEmptyState(
                    icon: const Icon(Icons.savings_outlined, size: 56),
                    title: 'No budgets for this month',
                    subtitle: 'Create a budget to monitor your spending.',
                    action: FilledButton.icon(
                      onPressed: () => BudgetEditorSheet.show(
                        context,
                        month: currentDate.month,
                        year: currentDate.year,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Budget'),
                    ),
                  );
                }

                final totalBudget = progressList.fold(
                    0.0, (sum, item) => sum + item.budget.amount);
                final totalSpent =
                    progressList.fold(0.0, (sum, item) => sum + item.spent);
                final totalRemaining = totalBudget - totalSpent;

                return RefreshIndicator(
                  onRefresh: () => controller.refresh(),
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: [
                      _OverallSummaryCard(
                        totalBudget: totalBudget,
                        totalSpent: totalSpent,
                        totalRemaining: totalRemaining,
                      ),
                      AppSpacing.vLg,
                      Text(
                        'Category Budgets',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      AppSpacing.vMd,
                      for (final progress in progressList)
                        CategoryBudgetCard(
                          progress: progress,
                          onTap: () => context.go(
                            Routes.budgetDetailPath(progress.budget.id),
                            extra: progress,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.currentDate,
    required this.onChanged,
  });

  final DateTime currentDate;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(
                DateTime(currentDate.year, currentDate.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy').format(currentDate),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(
                DateTime(currentDate.year, currentDate.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _OverallSummaryCard extends StatelessWidget {
  const _OverallSummaryCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
  });

  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;

  @override
  Widget build(BuildContext context) {
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final isOver = totalSpent > totalBudget;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Monthly Budget',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          AppSpacing.vXs,
          Text(
            totalBudget.formatCurrency(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          AppSpacing.vLg,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.expense,
                            shape: BoxShape.circle,
                          ),
                        ),
                        AppSpacing.hXs,
                        Text('Spent',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    AppSpacing.vXs,
                    Text(
                      totalSpent.formatCurrency(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOver ? AppColors.expense : AppColors.income,
                            shape: BoxShape.circle,
                          ),
                        ),
                        AppSpacing.hXs,
                        Text(isOver ? 'Over Limit' : 'Remaining',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    AppSpacing.vXs,
                    Text(
                      isOver
                          ? (totalSpent - totalBudget).formatCurrency()
                          : totalRemaining.formatCurrency(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOver ? AppColors.expense : AppColors.income,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.vLg,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                isOver ? AppColors.expense : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
