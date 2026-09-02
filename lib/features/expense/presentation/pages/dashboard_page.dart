import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/sync/sync_status_chip.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_list_controller.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';
import 'package:finora/features/expense/domain/entities/dashboard_summary.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/dashboard_controller.dart';
import 'package:finora/features/expense/presentation/widgets/balance_credit_card.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/features/expense/presentation/widgets/expense_card.dart';
import 'package:finora/features/expense/presentation/widgets/offline_banner.dart';
import 'package:finora/features/expense/presentation/widgets/pie_chart_widget.dart';
import 'package:finora/features/expense/presentation/widgets/quick_actions_card.dart';
import 'package:finora/features/ai/presentation/widgets/ai_dashboard_card.dart';
import 'package:finora/shared/widgets/finora_app_bar.dart';
import 'package:finora/shared/widgets/finora_avatar.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardControllerProvider);
    final name = ref.watch(authControllerProvider).user?.displayName ?? 'there';

    return Scaffold(
      appBar: FinoraAppBar(
        leading: GestureDetector(
          onTap: () => context.push(Routes.profile),
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: FinoraAvatar(
              displayName: name,
              radius: 18,
              background: Colors.white.withValues(alpha: 0.22),
              foreground: Colors.white,
            ),
          ),
        ),
        leadingWidth: 52,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $name',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Here’s your money at a glance',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
        actions: const [SyncStatusChip()],
      ),
      // Removed FAB as requested to replace with Quick Transaction card
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => FinoraEmptyState(
                icon: const Icon(Icons.error_outline, size: 56),
                title: 'Could not load dashboard',
                subtitle: e is Failure ? e.message : '$e',
                action: FilledButton(
                  onPressed: () =>
                      ref.read(dashboardControllerProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
      data: (summary) => RefreshIndicator(
        onRefresh: () =>
            ref.read(dashboardControllerProvider.notifier).refresh(),
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            AppSpacing.vMd,
            BalanceCreditCard(summary: summary, holderName: name),
            AppSpacing.vMd,
            const QuickActionsCard(),
            AppSpacing.vMd,
            const AiDashboardCard(),
            AppSpacing.vMd,
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Income (Month)',
                    amount: summary.monthlyIncome,
                    icon: Icons.arrow_downward,
                    color: AppColors.success,
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _StatTile(
                    label: 'Expense (Month)',
                    amount: summary.monthlyExpense,
                    icon: Icons.arrow_upward,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
            AppSpacing.vMd,
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Savings (Total)',
                    amount: summary.savings,
                    icon: Icons.savings,
                    color: Colors.blue,
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: _StatTile(
                    label: 'Today Expense',
                    amount: summary.todayExpense,
                    icon: Icons.today,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            AppSpacing.vLg,
            const _BudgetQuickView(),
            AppSpacing.vLg,
            _CategoryBreakdown(summary: summary),
            AppSpacing.vLg,
            _RecentSection(summary: summary),
            AppSpacing.vXxl,
          ],
        ),
      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            AppSpacing.vSm,
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            AppSpacing.vXs,
            Text(amount.formatCurrency(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.byCategory.isEmpty) return const SizedBox.shrink();
    final max = summary.byCategory.first.total;
    final top = summary.byCategory.take(5).toList();

    // The donut mirrors the same month-to-date figures as the bars below, so a
    // just-added or just-scanned expense is visible here immediately.
    final monthTotal =
        summary.byCategory.fold(0.0, (sum, slice) => sum + slice.total);
    final pieData = [
      for (final slice in summary.byCategory)
        PieChartEntry(
          categoryId: slice.categoryId,
          categoryName: slice.categoryName,
          color: slice.color,
          amount: slice.total,
          percentage: monthTotal > 0 ? slice.total / monthTotal * 100 : 0,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spending by category',
            style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.vMd,
        Center(
          child: FinoraPieChart(
            data: pieData,
            size: 168,
            strokeWidth: 26,
            centerLabel: 'This month',
            centerAmount: monthTotal.formatAmount(),
          ),
        ),
        AppSpacing.vLg,
        for (final slice in top)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(slice.categoryName,
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(slice.total.formatCurrency(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                AppSpacing.vXs,
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max <= 0 ? 0 : (slice.total / max).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                        CategoryVisuals.color(slice.color)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentSection extends ConsumerWidget {
  const _RecentSection({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryControllerProvider).valueOrNull ?? [];
    final categoryById = {for (final c in categories) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent transactions',
                style: Theme.of(context).textTheme.titleMedium),
            TextButton(
              onPressed: () => context.go(Routes.transactions),
              child: const Text('See all'),
            ),
          ],
        ),
        AppSpacing.vXs,
        if (summary.recentTransactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('No transactions yet')),
          )
        else
          for (final e in summary.recentTransactions)
            ExpenseCard(
              expense: e,
              category:
                  e.categoryId == null ? null : categoryById[e.categoryId],
              onTap: () => context.go(
                Routes.transactionDetailPath(e.id),
              ),
            ),
      ],
    );
  }
}

class _BudgetQuickView extends ConsumerWidget {
  const _BudgetQuickView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBudgets = ref.watch(budgetListControllerProvider);

    return asyncBudgets.maybeWhen(
      data: (progressList) {
        if (progressList.isEmpty) return const SizedBox.shrink();

        final totalBudget =
            progressList.fold(0.0, (sum, item) => sum + item.budget.amount);
        final totalSpent =
            progressList.fold(0.0, (sum, item) => sum + item.spent);
        final pct =
            totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
        final isOver = totalSpent > totalBudget;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Budget',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push(Routes.budgets),
                  child: const Text('Manage'),
                ),
              ],
            ),
            InkWell(
              onTap: () => context.push(Routes.budgets),
              borderRadius: AppRadius.cardRadius,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Spent: ${totalSpent.formatCurrency()}',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          isOver
                              ? 'Over by ${(totalSpent - totalBudget).formatCurrency()}'
                              : '${(totalBudget - totalSpent).formatCurrency()} left',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isOver
                                    ? AppColors.expense
                                    : AppColors.income,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    AppSpacing.vSm,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                            isOver ? AppColors.expense : AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
