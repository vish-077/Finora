import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';

abstract interface class ExpenseRepository {
  /// Offline-first: returns cached data immediately, refreshing from Firestore
  /// in the background when online.
  Future<Either<Failure, List<Expense>>> getExpenses({ExpenseFilter? filter});

  Future<Either<Failure, Expense>> getExpenseById(String id);

  Future<Either<Failure, List<Expense>>> getRecentTransactions({int limit = 5});

  Future<Either<Failure, Expense>> addExpense(Expense expense);

  Future<Either<Failure, Expense>> updateExpense(Expense expense);

  Future<Either<Failure, Unit>> deleteExpense(String id);

  /// Emits the full expense list whenever the backend changes (realtime).
  Stream<List<Expense>> watchExpenses();

  List<Expense> applyFilter(List<Expense> list, ExpenseFilter? filter);
}
