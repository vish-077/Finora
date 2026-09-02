import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/features/budget/domain/repositories/budget_repository.dart';
import 'package:finora/features/budget/domain/use_cases/budget_use_cases.dart';

import 'package:finora/features/budget/domain/entities/budget.dart';

part 'budget_providers.g.dart';

@riverpod
BudgetRepository budgetRepository(BudgetRepositoryRef ref) =>
    sl<BudgetRepository>();

@riverpod
GetBudgetsUseCase getBudgetsUseCase(GetBudgetsUseCaseRef ref) =>
    sl<GetBudgetsUseCase>();

@riverpod
AddBudgetUseCase addBudgetUseCase(AddBudgetUseCaseRef ref) =>
    sl<AddBudgetUseCase>();

@riverpod
UpdateBudgetUseCase updateBudgetUseCase(UpdateBudgetUseCaseRef ref) =>
    sl<UpdateBudgetUseCase>();

@riverpod
DeleteBudgetUseCase deleteBudgetUseCase(DeleteBudgetUseCaseRef ref) =>
    sl<DeleteBudgetUseCase>();

@riverpod
Stream<List<Budget>> budgetsStream(BudgetsStreamRef ref, {required int month, required int year}) {
  return ref.watch(budgetRepositoryProvider).watchBudgets(month, year);
}
