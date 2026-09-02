import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class AddExpenseUseCase {
  const AddExpenseUseCase(this._repo);
  final ExpenseRepository _repo;

  Future<Either<Failure, Expense>> call(Expense expense) {
    if (expense.title.trim().isEmpty) {
      return Future.value(
        left(const ValidationFailure('Title is required', field: 'title')),
      );
    }
    if (expense.amount <= 0) {
      return Future.value(
        left(const ValidationFailure('Amount must be greater than 0',
            field: 'amount')),
      );
    }
    return _repo.addExpense(expense);
  }
}
