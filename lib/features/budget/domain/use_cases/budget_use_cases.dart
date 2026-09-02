import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/domain/repositories/budget_repository.dart';

class GetBudgetsUseCase {
  const GetBudgetsUseCase(this.repository);
  final BudgetRepository repository;

  Future<Either<Failure, List<Budget>>> call(int month, int year) {
    return repository.getBudgets(month, year);
  }
}

class AddBudgetUseCase {
  const AddBudgetUseCase(this.repository);
  final BudgetRepository repository;

  Future<Either<Failure, Budget>> call({
    required String userId,
    required String categoryId,
    required int month,
    required int year,
    required double amount,
  }) async {
    if (amount <= 0) {
      return left(const ValidationFailure('Budget amount must be greater than zero'));
    }
    
    // Create new budget with a generated ID
    final budget = Budget(
      id: const Uuid().v4(),
      userId: userId,
      categoryId: categoryId,
      month: month,
      year: year,
      amount: amount,
    );
    
    return repository.addBudget(budget);
  }
}

class UpdateBudgetUseCase {
  const UpdateBudgetUseCase(this.repository);
  final BudgetRepository repository;

  Future<Either<Failure, Budget>> call(Budget budget) async {
    if (budget.amount <= 0) {
      return left(const ValidationFailure('Budget amount must be greater than zero'));
    }
    return repository.updateBudget(budget);
  }
}

class DeleteBudgetUseCase {
  const DeleteBudgetUseCase(this.repository);
  final BudgetRepository repository;

  Future<Either<Failure, Unit>> call(String id) {
    return repository.deleteBudget(id);
  }
}
