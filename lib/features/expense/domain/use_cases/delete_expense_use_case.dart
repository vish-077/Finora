import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class DeleteExpenseUseCase {
  const DeleteExpenseUseCase(this._repo);
  final ExpenseRepository _repo;

  Future<Either<Failure, Unit>> call(String id) => _repo.deleteExpense(id);
}
