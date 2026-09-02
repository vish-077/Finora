import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/use_cases/add_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/delete_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/update_expense_use_case.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/shared/enums/transaction_type.dart';

// Simple mock implementation
class _MockExpenseRepository implements ExpenseRepository {
  Expense? lastAdded;
  Expense? lastUpdated;
  String? lastDeletedId;

  @override
  Future<Either<Failure, Expense>> addExpense(Expense expense) async {
    lastAdded = expense;
    return right(expense);
  }

  @override
  Future<Either<Failure, Unit>> deleteExpense(String id) async {
    lastDeletedId = id;
    return right(unit);
  }

  @override
  Future<Either<Failure, Expense>> updateExpense(Expense expense) async {
    lastUpdated = expense;
    return right(expense);
  }

  @override
  Future<Either<Failure, List<Expense>>> getExpenses({ExpenseFilter? filter}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Expense>> getExpenseById(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<Expense>>> getRecentTransactions({int limit = 5}) =>
      throw UnimplementedError();

  @override
  Stream<List<Expense>> watchExpenses() => throw UnimplementedError();

  @override
  List<Expense> applyFilter(List<Expense> list, ExpenseFilter? filter) => [];
}

void main() {
  late _MockExpenseRepository mockRepo;

  setUp(() {
    mockRepo = _MockExpenseRepository();
  });

  group('AddExpenseUseCase', () {
    late AddExpenseUseCase useCase;

    setUp(() => useCase = AddExpenseUseCase(mockRepo));

    test('returns ValidationFailure when title is empty', () async {
      const expense = Expense(
        id: '',
        userId: 'u1',
        title: '',
        amount: 100,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _testDate,
      );
      final result = await useCase(expense);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('Should be left'),
      );
    });

    test('returns ValidationFailure when amount is zero', () async {
      const expense = Expense(
        id: '',
        userId: 'u1',
        title: 'Test',
        amount: 0,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _testDate,
      );
      final result = await useCase(expense);
      expect(result.isLeft(), isTrue);
    });

    test('returns ValidationFailure when amount is negative', () async {
      const expense = Expense(
        id: '',
        userId: 'u1',
        title: 'Test',
        amount: -50,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _testDate,
      );
      final result = await useCase(expense);
      expect(result.isLeft(), isTrue);
    });

    test('calls repository when valid', () async {
      const expense = Expense(
        id: '',
        userId: 'u1',
        title: 'Groceries',
        amount: 100,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _testDate,
      );
      final result = await useCase(expense);
      expect(result.isRight(), isTrue);
      expect(mockRepo.lastAdded?.title, 'Groceries');
    });
  });

  group('UpdateExpenseUseCase', () {
    late UpdateExpenseUseCase useCase;

    setUp(() => useCase = UpdateExpenseUseCase(mockRepo));

    test('returns ValidationFailure for empty title', () async {
      const expense = Expense(
        id: 'existing-id',
        userId: 'u1',
        title: '  ',
        amount: 100,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _testDate,
      );
      final result = await useCase(expense);
      expect(result.isLeft(), isTrue);
    });

    test('calls repository when valid', () async {
      const expense = Expense(
        id: 'existing-id',
        userId: 'u1',
        title: 'Updated',
        amount: 200,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.upi,
        transactionDate: _testDate,
      );
      final result = await useCase(expense);
      expect(result.isRight(), isTrue);
      expect(mockRepo.lastUpdated?.title, 'Updated');
    });
  });

  group('DeleteExpenseUseCase', () {
    late DeleteExpenseUseCase useCase;

    setUp(() => useCase = DeleteExpenseUseCase(mockRepo));

    test('calls repository delete', () async {
      final result = await useCase('expense-id');
      expect(result.isRight(), isTrue);
      expect(mockRepo.lastDeletedId, 'expense-id');
    });
  });
}

const _testDate = _FixedDateTime();

class _FixedDateTime implements DateTime {
  const _FixedDateTime();

  @override int get year => 2026;
  @override int get month => 7;
  @override int get day => 15;
  @override int get hour => 10;
  @override int get minute => 30;
  @override int get second => 0;
  @override int get millisecond => 0;
  @override int get microsecond => 0;

  @override String toIso8601String() => '2026-07-15T10:30:00.000';
  @override String toString() => toIso8601String();
  @override DateTime toLocal() => DateTime(2026, 7, 15, 10, 30);
  @override DateTime toUtc() => DateTime.utc(2026, 7, 15, 10, 30);

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
