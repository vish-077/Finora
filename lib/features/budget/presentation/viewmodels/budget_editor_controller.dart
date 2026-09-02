import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_list_controller.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_providers.dart';

part 'budget_editor_controller.g.dart';

@riverpod
class BudgetEditorController extends _$BudgetEditorController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<Failure?> saveBudget({
    Budget? existingBudget,
    required String categoryId,
    required double amount,
    required int month,
    required int year,
  }) async {
    state = const AsyncLoading();

    final userId = ref.read(authControllerProvider).user?.id;
    if (userId == null) {
      state = const AsyncData(null);
      return const LocalFailure('User not authenticated');
    }

    // Validation: prevent duplicate budget for same category/month
    if (existingBudget == null) {
      final budgetsResult = await ref.read(getBudgetsUseCaseProvider)(month, year);
      if (budgetsResult.isRight()) {
        final budgets = budgetsResult.getRight().toNullable()!;
        final exists = budgets.any((b) => b.categoryId == categoryId);
        if (exists) {
          state = const AsyncData(null);
          return const ValidationFailure('A budget for this category already exists this month.');
        }
      }
    }

    Failure? failure;
    if (existingBudget != null) {
      final updateResult = await ref.read(updateBudgetUseCaseProvider)(
        existingBudget.copyWith(
          categoryId: categoryId,
          amount: amount,
          month: month,
          year: year,
        ),
      );
      updateResult.fold((f) => failure = f, (_) => null);
    } else {
      final addResult = await ref.read(addBudgetUseCaseProvider)(
        userId: userId,
        categoryId: categoryId,
        month: month,
        year: year,
        amount: amount,
      );
      addResult.fold((f) => failure = f, (_) => null);
    }

    if (failure != null) {
      state = AsyncError(failure!, StackTrace.current);
      return failure;
    }

    state = const AsyncData(null);
    ref.invalidate(budgetListControllerProvider);
    return null;
  }
}
