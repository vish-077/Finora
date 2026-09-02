import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

/// Creates a copy of an existing expense (new id assigned by the data layer,
/// dated [now]).
class DuplicateExpenseUseCase {
  const DuplicateExpenseUseCase(this._repo);
  final ExpenseRepository _repo;

  Future<Either<Failure, Expense>> call(Expense source, {DateTime? now}) {
    final copy = source.copyWith(
      id: '', // data layer assigns a fresh id
      title: source.title,
      transactionDate: now ?? source.transactionDate,
    );
    return _repo.addExpense(copy);
  }
}
