import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class GetRecentTransactionsUseCase {
  const GetRecentTransactionsUseCase(this._repo);
  final ExpenseRepository _repo;

  Future<Either<Failure, List<Expense>>> call({int limit = 5}) =>
      _repo.getRecentTransactions(limit: limit);
}
