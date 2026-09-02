import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/features/expense/presentation/viewmodels/analytics_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/dashboard_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';
import 'package:finora/features/expense/presentation/viewmodels/filter_controller.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_dashboard_controller.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_list_controller.dart';

part 'expense_list_controller.g.dart';

/// Loads the filtered expense list. Rebuilds automatically when the filter
/// changes (it watches [filterControllerProvider]).
@riverpod
class ExpenseListController extends _$ExpenseListController {
  @override
  FutureOr<List<Expense>> build() {
    final filter = ref.watch(filterControllerProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    if (expensesAsync.hasValue) {
      final repo = ref.read(expenseRepositoryProvider);
      return repo.applyFilter(expensesAsync.value!, filter);
    }

    return _load(filter);
  }

  Future<List<Expense>> _load(ExpenseFilter filter) async {
    final result = await ref.read(getExpensesUseCaseProvider)(filter: filter);
    return result.fold((failure) => throw failure, (list) => list);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _load(ref.read(filterControllerProvider)));
  }

  void _invalidateDependents() {
    ref.invalidateSelf();
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(analyticsControllerProvider);
    ref.invalidate(aiDashboardControllerProvider);
    ref.invalidate(budgetListControllerProvider);
  }

  Future<Failure?> deleteExpense(String id) async {
    final result = await ref.read(deleteExpenseUseCaseProvider)(id);
    return result.fold((f) => f, (_) {
      _invalidateDependents();
      return null;
    });
  }

  Future<Failure?> duplicateExpense(Expense source) async {
    final result = await ref.read(duplicateExpenseUseCaseProvider)(
      source,
      now: DateTime.now(),
    );
    return result.fold((f) => f, (_) {
      _invalidateDependents();
      return null;
    });
  }
}
