import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class GetExpenseByIdUseCase {
  const GetExpenseByIdUseCase(this._repo);
  final ExpenseRepository _repo;

  Future<Either<Failure, Expense>> call(String id) => _repo.getExpenseById(id);
}
