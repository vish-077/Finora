import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/presentation/pages/add_expense_page.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_list_controller.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class ExpenseDetailPage extends ConsumerWidget {
  const ExpenseDetailPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListControllerProvider).valueOrNull ?? [];
    final expense = expenses.where((e) => e.id == expenseId).firstOrNull;
    final categories = ref.watch(categoryControllerProvider).valueOrNull ?? [];

    if (expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const FinoraEmptyState(
          icon: Icon(Icons.search_off, size: 56),
          title: 'Transaction not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    }

    final category =
        categories.where((c) => c.id == expense.categoryId).firstOrNull;
    final color = category == null
        ? AppColors.primaryLight
        : CategoryVisuals.color(category.color);
    final amountColor = expense.isIncome ? AppColors.income : AppColors.expense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: [
          IconButton(
            tooltip: 'Duplicate',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final failure = await ref
                  .read(expenseListControllerProvider.notifier)
                  .duplicateExpense(expense);
              if (context.mounted) {
                showAuthSnack(
                  context,
                  failure == null ? 'Duplicated' : failure.message,
                  isError: failure != null,
                );
                if (failure == null) Navigator.of(context).pop();
              }
            },
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go(
              Routes.transactionEditPath(expense.id),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppSpacing.vLg,
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CategoryVisuals.icon(category?.icon ?? 'category'),
                      color: color, size: 34),
                ),
                AppSpacing.vMd,
                Text(expense.title,
                    style: Theme.of(context).textTheme.titleLarge),
                AppSpacing.vXs,
                Text(
                  '${expense.isIncome ? '+' : '-'}${expense.amount.formatCurrency()}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          AppSpacing.vXl,
          _DetailRow(
            icon: Icons.category_outlined,
            label: 'Category',
            value: category?.name ?? 'Uncategorized',
          ),
          _DetailRow(
            icon: Icons.swap_vert,
            label: 'Type',
            value: expense.transactionType.label,
          ),
          _DetailRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payment method',
            value: expense.paymentMethod.label,
          ),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('EEEE, d MMM yyyy').format(expense.transactionDate),
          ),
          _DetailRow(
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: DateFormat('h:mm a').format(expense.transactionDate),
          ),
          if (expense.notes != null && expense.notes!.isNotEmpty)
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
              value: expense.notes!,
            ),
          AppSpacing.vXl,
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete transaction'),
            onPressed: () => _delete(context, ref, expense),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('“${expense.title}” will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final failure = await ref
        .read(expenseListControllerProvider.notifier)
        .deleteExpense(expense.id);
    if (context.mounted) {
      showAuthSnack(context, failure == null ? 'Deleted' : failure.message,
          isError: failure != null);
      if (failure == null) context.go(Routes.transactions);
    }
  }
}

/// Wrapper that loads an existing expense by ID and opens the editor.
/// Used by GoRouter for the `/home/transactions/:id/edit` route.
class EditExpenseWrapper extends ConsumerWidget {
  const EditExpenseWrapper({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expenseListControllerProvider).valueOrNull ?? [];
    final expense = expenses.where((e) => e.id == expenseId).firstOrNull;

    if (expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit')),
        body: const FinoraEmptyState(
          icon: Icon(Icons.search_off, size: 56),
          title: 'Transaction not found',
          subtitle: 'It may have been deleted.',
        ),
      );
    }

    return AddExpensePage(existing: expense);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            AppSpacing.hMd,
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
}
