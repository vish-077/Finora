import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/presentation/viewmodels/analytics_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/dashboard_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_list_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_dashboard_controller.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_list_controller.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/core/logging/log_service.dart' as finora_log;
import 'package:finora/core/services/notification_service.dart' as finora_notif;
import 'package:finora/features/budget/domain/repositories/budget_repository.dart' as finora_budget_repo;
import 'package:finora/features/expense/domain/entities/expense_filter.dart' as finora_filter;
import 'package:finora/shared/enums/transaction_type.dart';

part 'add_expense_controller.g.dart';

/// Drives the Add/Edit Expense form. `state` is the submit operation status.
@riverpod
class AddExpenseController extends _$AddExpenseController {
  @override
  FutureOr<void> build() {}

  String get _userId =>
      ref.read(authControllerProvider).user?.id ?? 'local-user';

  Future<bool> save({
    String? id,
    required String title,
    required double amount,
    required String? categoryId,
    required String? accountId,
    required TransactionType transactionType,
    required DateTime transactionDate,
    String? notes,
  }) async {
    state = const AsyncLoading();

    final expense = Expense(
      id: id ?? '',
      userId: _userId,
      title: title.trim(),
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      paymentMethod: PaymentMethod.cash, // Deprecated, mapped to cash for fallback
      transactionType: transactionType,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
      transactionDate: transactionDate,
    );

    final isEditing = id != null && id.isNotEmpty;
    final result = isEditing
        ? await ref.read(updateExpenseUseCaseProvider)(expense)
        : await ref.read(addExpenseUseCaseProvider)(expense);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) async {
        // Budget Checking Logic
        if (transactionType == TransactionType.expense && categoryId != null) {
          await _checkBudgetLimit(categoryId, transactionDate);
        }

        // Every read model derived from the transaction table has to be
        // dropped, not just the list and the dashboard — the analytics pie /
        // donut chart and the AI health score were previously left stale, so a
        // freshly added (or scanned) expense never showed up in them.
        ref.invalidate(expenseListControllerProvider);
        ref.invalidate(dashboardControllerProvider);
        ref.invalidate(analyticsControllerProvider);
        ref.invalidate(aiDashboardControllerProvider);
        ref.invalidate(budgetListControllerProvider);
        state = const AsyncData(null);
        return true;
      },
    );
  }

  Future<void> _checkBudgetLimit(String categoryId, DateTime date) async {
    try {
      // We will read the budget list controller to see the current progress
      // But since we just added an expense, we need to refresh the budget list first
      // Or we can manually calculate it by fetching the budget and all expenses.
      // For simplicity, we can rely on the existing BudgetListController.
      // Wait, BudgetListController builds for the current month.
      final budgetResult = await sl<finora_budget_repo.BudgetRepository>().getBudgets(date.month, date.year);
      
      if (budgetResult.isLeft()) return;
      final budgets = budgetResult.getRight().toNullable()!;
      
      final budget = budgets.where((b) => b.categoryId == categoryId).firstOrNull;
      if (budget == null) return;

      // Get all expenses for this month to calculate spent
      final filter = finora_filter.ExpenseFilter(
        preset: finora_filter.DateRangePreset.custom,
        categoryId: categoryId,
        customStart: DateTime(date.year, date.month, 1),
        customEnd: DateTime(date.year, date.month + 1, 1),
      );
      final expensesResult = await ref.read(getExpensesUseCaseProvider)(filter: filter);
      if (expensesResult.isLeft()) return;
      final expenses = expensesResult.getRight().toNullable()!;

      double spent = 0;
      for (final ex in expenses) {
        if (ex.isExpense) spent += ex.amount;
      }

      final percentage = spent / budget.amount;
      
      if (percentage >= 1.0) {
        await finora_notif.NotificationService().showBudgetWarning(
          id: categoryId.hashCode,
          title: 'Budget Exceeded!',
          body: 'You have exceeded your monthly budget for this category.',
        );
      } else if (percentage >= 0.8) {
        await finora_notif.NotificationService().showBudgetWarning(
          id: categoryId.hashCode,
          title: 'Budget Warning',
          body: 'You have used ${(percentage * 100).toStringAsFixed(0)}% of your monthly budget.',
        );
      }
    } catch (e) {
      // Silent catch for notification errors so it doesn't break expense adding
      finora_log.LogService.e('Failed to check budget limits: $e');
    }
  }
}
