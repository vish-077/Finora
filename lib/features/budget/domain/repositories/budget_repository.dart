import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';

abstract class BudgetRepository {
  /// Fetches all budgets for a given month and year.
  Future<Either<Failure, List<Budget>>> getBudgets(int month, int year);

  /// Watches all budgets for a given month and year.
  Stream<List<Budget>> watchBudgets(int month, int year);

  /// Adds a new budget.
  Future<Either<Failure, Budget>> addBudget(Budget budget);

  /// Updates an existing budget.
  Future<Either<Failure, Budget>> updateBudget(Budget budget);

  /// Deletes a budget by ID.
  Future<Either<Failure, Unit>> deleteBudget(String id);
}
