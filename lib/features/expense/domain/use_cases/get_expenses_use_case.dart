import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class GetExpensesUseCase {
  const GetExpensesUseCase(this._repo);
  final ExpenseRepository _repo;

  Future<Either<Failure, List<Expense>>> call({ExpenseFilter? filter}) =>
      _repo.getExpenses(filter: filter);
}
