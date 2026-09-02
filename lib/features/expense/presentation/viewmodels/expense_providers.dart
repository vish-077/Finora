import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';
import 'package:finora/features/expense/domain/use_cases/add_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/category_use_cases.dart';
import 'package:finora/features/expense/domain/use_cases/delete_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/duplicate_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_analytics_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_dashboard_summary_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_expense_by_id_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_expenses_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_recent_transactions_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/update_expense_use_case.dart';

import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/category.dart';

part 'expense_providers.g.dart';

@riverpod
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) =>
    sl<ExpenseRepository>();

@riverpod
CategoryRepository categoryRepository(CategoryRepositoryRef ref) =>
    sl<CategoryRepository>();

@riverpod
GetExpensesUseCase getExpensesUseCase(GetExpensesUseCaseRef ref) =>
    sl<GetExpensesUseCase>();

@riverpod
GetExpenseByIdUseCase getExpenseByIdUseCase(GetExpenseByIdUseCaseRef ref) =>
    sl<GetExpenseByIdUseCase>();

@riverpod
GetRecentTransactionsUseCase getRecentTransactionsUseCase(
        GetRecentTransactionsUseCaseRef ref) =>
    sl<GetRecentTransactionsUseCase>();

@riverpod
AddExpenseUseCase addExpenseUseCase(AddExpenseUseCaseRef ref) =>
    sl<AddExpenseUseCase>();

@riverpod
UpdateExpenseUseCase updateExpenseUseCase(UpdateExpenseUseCaseRef ref) =>
    sl<UpdateExpenseUseCase>();

@riverpod
DeleteExpenseUseCase deleteExpenseUseCase(DeleteExpenseUseCaseRef ref) =>
    sl<DeleteExpenseUseCase>();

@riverpod
DuplicateExpenseUseCase duplicateExpenseUseCase(
        DuplicateExpenseUseCaseRef ref) =>
    sl<DuplicateExpenseUseCase>();

@riverpod
GetCategoriesUseCase getCategoriesUseCase(GetCategoriesUseCaseRef ref) =>
    sl<GetCategoriesUseCase>();

@riverpod
AddCategoryUseCase addCategoryUseCase(AddCategoryUseCaseRef ref) =>
    sl<AddCategoryUseCase>();

@riverpod
UpdateCategoryUseCase updateCategoryUseCase(UpdateCategoryUseCaseRef ref) =>
    sl<UpdateCategoryUseCase>();

@riverpod
DeleteCategoryUseCase deleteCategoryUseCase(DeleteCategoryUseCaseRef ref) =>
    sl<DeleteCategoryUseCase>();

@riverpod
GetDashboardSummaryUseCase getDashboardSummaryUseCase(
        GetDashboardSummaryUseCaseRef ref) =>
    sl<GetDashboardSummaryUseCase>();

@riverpod
GetAnalyticsUseCase getAnalyticsUseCase(GetAnalyticsUseCaseRef ref) =>
    sl<GetAnalyticsUseCase>();

@riverpod
Stream<List<Expense>> expensesStream(ExpensesStreamRef ref) {
  return ref.watch(expenseRepositoryProvider).watchExpenses();
}

@riverpod
Stream<List<Category>> categoriesStream(CategoriesStreamRef ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
}
