import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/context_extensions.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_list_controller.dart';
import 'package:finora/features/budget/presentation/widgets/budget_editor_sheet.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/features/expense/presentation/widgets/expense_card.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({
    super.key,
    required this.budgetId,
    required this.progress,
  });

  final String budgetId;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep watching the controller so we get updates when edited
    final asyncBudgets = ref.watch(budgetListControllerProvider);

    // Fallback to the passed progress if loading/error, otherwise find updated one
    BudgetProgress currentProgress = progress;
    if (asyncBudgets.hasValue) {
      final updated = asyncBudgets.value!.where((b) => b.budget.id == budgetId);
      if (updated.isNotEmpty) {
        currentProgress = updated.first;
      }
    }

    final budget = currentProgress.budget;
    final statusColor = _getStatusColor(currentProgress.status);
    final statusText = _getStatusText(currentProgress.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => BudgetEditorSheet.show(
              context,
              budget: budget,
              month: budget.month,
              year: budget.year,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.expense),
            onPressed: () => _confirmDelete(context, ref, budget.id),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppSpacing.vMd,
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: CategoryVisuals.color(currentProgress.categoryColor)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CategoryVisuals.icon(currentProgress.categoryIcon),
                color: CategoryVisuals.color(currentProgress.categoryColor),
                size: 48,
              ),
            ),
          ),
          AppSpacing.vSm,
          Center(
            child: Text(
              currentProgress.categoryName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          AppSpacing.vXl,
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: currentProgress.percentage.clamp(0.0, 1.0),
                        strokeWidth: 12,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(statusColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(currentProgress.percentage * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                        ),
                        Text(
                          statusText,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                AppSpacing.vXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DetailStat(
                      label: 'Spent',
                      amount: currentProgress.spent,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    _DetailStat(
                      label: 'Remaining',
                      amount: currentProgress.remaining > 0
                          ? currentProgress.remaining
                          : 0,
                      color: currentProgress.remaining >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ],
                ),
                AppSpacing.vMd,
                Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                AppSpacing.vMd,
                Text(
                  'Total Budget: ${budget.amount.formatCurrency()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          AppSpacing.vXl,
          Text(
            'Related Expenses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          AppSpacing.vMd,
          _RelatedExpensesList(
            categoryId: budget.categoryId,
            month: budget.month,
            year: budget.year,
          ),
          AppSpacing.vXxl,
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      final failure = await ref
          .read(budgetListControllerProvider.notifier)
          .deleteBudget(id);
      if (failure != null) {
        if (context.mounted) context.showSnackBar(failure.message, isError: true);
      } else {
        if (context.mounted) {
          context.showSnackBar('Budget deleted');
          context.pop();
        }
      }
    }
  }

  Color _getStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return AppColors.income;
      case BudgetStatus.warning:
        return AppColors.warning;
      case BudgetStatus.overLimit:
        return AppColors.expense;
    }
  }

  String _getStatusText(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return 'Safe';
      case BudgetStatus.warning:
        return 'Warning';
      case BudgetStatus.overLimit:
        return 'Over Limit';
    }
  }
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        AppSpacing.vXs,
        Text(
          amount.formatCurrency(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

// Internal provider to fetch expenses for the specific category/month
final _relatedExpensesProvider = FutureProvider.family<List<Expense>, Budget>(
  (ref, budget) async {
    final filter = ExpenseFilter(
      preset: DateRangePreset.custom,
      categoryId: budget.categoryId,
      customStart: DateTime(budget.year, budget.month, 1),
      customEnd: DateTime(budget.year, budget.month + 1, 1),
    );
    final result = await ref.read(getExpensesUseCaseProvider)(filter: filter);
    return result.fold((f) => throw f, (list) => list);
  },
);

class _RelatedExpensesList extends ConsumerWidget {
  const _RelatedExpensesList({
    required this.categoryId,
    required this.month,
    required this.year,
  });

  final String categoryId;
  final int month;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dummyBudget = Budget(
      id: '',
      userId: '',
      categoryId: categoryId,
      month: month,
      year: year,
      amount: 0,
    );
    final asyncExpenses = ref.watch(_relatedExpensesProvider(dummyBudget));

    return asyncExpenses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading expenses: $e')),
      data: (expenses) {
        if (expenses.isEmpty) {
          return const FinoraEmptyState(
            icon: Icon(Icons.receipt_long, size: 48),
            title: 'No expenses yet',
            subtitle: 'Expenses for this category will appear here.',
          );
        }

        return Column(
          children: [
            for (final ex in expenses)
              // Wrap in ignore pointer or pass null category since we already know the category context
              ExpenseCard(
                expense: ex,
                category: null,
                onTap: null, // Could optionally route to transaction detail
              ),
          ],
        );
      },
    );
  }
}
