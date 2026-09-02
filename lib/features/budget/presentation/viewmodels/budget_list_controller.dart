import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_providers.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';

part 'budget_list_controller.g.dart';

@riverpod
class BudgetListController extends _$BudgetListController {
  DateTime _currentDate = DateTime.now();

  DateTime get currentDate => _currentDate;

  @override
  FutureOr<List<BudgetProgress>> build() {
    final month = _currentDate.month;
    final year = _currentDate.year;

    final budgetsAsync = ref.watch(budgetsStreamProvider(month: month, year: year));
    final expensesAsync = ref.watch(expensesStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    if (budgetsAsync.hasValue && expensesAsync.hasValue && categoriesAsync.hasValue) {
      final budgets = budgetsAsync.value!;
      final expenses = expensesAsync.value!;
      final categories = categoriesAsync.value!;

      if (budgets.isEmpty) return [];

      final categoryMap = {for (final c in categories) c.id: c};
      final progressList = <BudgetProgress>[];

      for (final budget in budgets) {
        final category = categoryMap[budget.categoryId];
        if (category == null) continue;

        double spent = 0;
        final startOfMonth = DateTime(year, month, 1);
        final endOfMonth = DateTime(year, month + 1, 1);

        for (final ex in expenses) {
          if (ex.categoryId == budget.categoryId &&
              ex.isExpense &&
              !ex.transactionDate.isBefore(startOfMonth) &&
              ex.transactionDate.isBefore(endOfMonth)) {
            spent += ex.amount;
          }
        }

        progressList.add(BudgetProgress(
          budget: budget,
          categoryName: category.name,
          categoryColor: category.color,
          categoryIcon: category.icon,
          spent: spent,
        ));
      }
      return progressList;
    }

    return _load();
  }

  Future<List<BudgetProgress>> _load() async {
    final getBudgets = ref.read(getBudgetsUseCaseProvider);
    final getExpenses = ref.read(getExpensesUseCaseProvider);
    final getCategories = ref.read(getCategoriesUseCaseProvider);

    final month = _currentDate.month;
    final year = _currentDate.year;

    // 1. Fetch budgets for current month
    final budgetResult = await getBudgets(month, year);
    if (budgetResult.isLeft()) throw budgetResult.getLeft().toNullable()!;
    final budgets = budgetResult.getRight().toNullable()!;

    if (budgets.isEmpty) return [];

    // 2. Fetch all expenses for current month
    // Note: We use thisMonth preset and resolve it to start/end dates
    final filter = ExpenseFilter(preset: DateRangePreset.thisMonth);
    // Since DateRangePreset.thisMonth relies on DateTime.now(), we need to override the logic if _currentDate is not now.
    // For exact month querying:
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final expensesResult = await getExpenses(
        filter: ExpenseFilter(
            preset: DateRangePreset.custom,
            customStart: startOfMonth,
            customEnd: endOfMonth));
    if (expensesResult.isLeft()) throw expensesResult.getLeft().toNullable()!;
    final expenses = expensesResult.getRight().toNullable()!;

    // 3. Fetch categories
    final categoriesResult = await getCategories();
    final categories = categoriesResult.getRight().toNullable() ?? [];
    final categoryMap = {for (final c in categories) c.id: c};

    // 4. Calculate progress
    final progressList = <BudgetProgress>[];
    for (final budget in budgets) {
      final category = categoryMap[budget.categoryId];
      if (category == null) continue;

      // Sum expenses for this category
      double spent = 0;
      for (final ex in expenses) {
        if (ex.categoryId == budget.categoryId && ex.isExpense) {
          spent += ex.amount;
        }
      }

      progressList.add(BudgetProgress(
        budget: budget,
        categoryName: category.name,
        categoryColor: category.color,
        categoryIcon: category.icon,
        spent: spent,
      ));
    }

    return progressList;
  }

  void changeMonth(int month, int year) {
    _currentDate = DateTime(year, month);
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<Failure?> deleteBudget(String id) async {
    final result = await ref.read(deleteBudgetUseCaseProvider)(id);
    return result.fold((f) => f, (_) {
      ref.invalidateSelf();
      return null;
    });
  }
}
