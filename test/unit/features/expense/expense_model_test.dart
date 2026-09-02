import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/expense/data/models/expense_model.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/shared/enums/transaction_type.dart';

void main() {
  group('ExpenseModel', () {
    const testExpense = Expense(
      id: 'test-1',
      userId: 'user-1',
      title: 'Test Expense',
      amount: 100.50,
      categoryId: 'cat-food',
      paymentMethod: PaymentMethod.upi,
      transactionType: TransactionType.expense,
      notes: 'Test notes',
      transactionDate: _fixedDate,
    );

    test('fromEntity preserves all fields', () {
      final model = ExpenseModel.fromEntity(testExpense);
      expect(model.id, testExpense.id);
      expect(model.userId, testExpense.userId);
      expect(model.title, testExpense.title);
      expect(model.amount, testExpense.amount);
      expect(model.categoryId, testExpense.categoryId);
      expect(model.paymentMethod, testExpense.paymentMethod);
      expect(model.transactionType, testExpense.transactionType);
      expect(model.notes, testExpense.notes);
      expect(model.transactionDate, testExpense.transactionDate);
    });

    test('toCache and fromMap round-trip', () {
      final model = ExpenseModel.fromEntity(testExpense);
      final cache = model.toCache();
      final restored = ExpenseModel.fromMap(cache);
      expect(restored.id, model.id);
      expect(restored.userId, model.userId);
      expect(restored.title, model.title);
      expect(restored.amount, model.amount);
      expect(restored.categoryId, model.categoryId);
      expect(restored.paymentMethod, model.paymentMethod);
      expect(restored.transactionType, model.transactionType);
      expect(restored.notes, model.notes);
    });

    test('fromMap handles null fields gracefully', () {
      final map = <String, dynamic>{
        'id': 'id-1',
        'user_id': 'user-1',
        'amount': 42,
        'transaction_date': '2026-01-15T10:00:00.000',
      };
      final model = ExpenseModel.fromMap(map);
      expect(model.title, isEmpty);
      expect(model.notes, isNull);
      expect(model.categoryId, isNull);
      expect(model.paymentMethod, PaymentMethod.cash);
      expect(model.transactionType, TransactionType.expense);
    });

    test('toInsert excludes id and audit timestamps', () {
      final model = ExpenseModel.fromEntity(testExpense);
      final insert = model.toInsert();
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
      expect(insert.containsKey('updated_at'), isFalse);
      expect(insert['user_id'], testExpense.userId);
      expect(insert['title'], testExpense.title);
      expect(insert['amount'], testExpense.amount);
    });
  });

  group('Expense entity', () {
    test('isIncome returns true for income type', () {
      const expense = Expense(
        id: '1',
        userId: 'u1',
        title: 'Salary',
        amount: 50000,
        transactionType: TransactionType.income,
        paymentMethod: PaymentMethod.bankTransfer,
        transactionDate: _fixedDate,
      );
      expect(expense.isIncome, isTrue);
      expect(expense.isExpense, isFalse);
      expect(expense.signedAmount, 50000);
    });

    test('signedAmount is negative for expense', () {
      const expense = Expense(
        id: '1',
        userId: 'u1',
        title: 'Groceries',
        amount: 200,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _fixedDate,
      );
      expect(expense.signedAmount, -200);
    });

    test('copyWith preserves unchanged fields', () {
      const original = Expense(
        id: '1',
        userId: 'u1',
        title: 'Original',
        amount: 100,
        transactionType: TransactionType.expense,
        paymentMethod: PaymentMethod.cash,
        transactionDate: _fixedDate,
      );
      final copy = original.copyWith(title: 'Updated');
      expect(copy.title, 'Updated');
      expect(copy.id, original.id);
      expect(copy.amount, original.amount);
      expect(copy.userId, original.userId);
    });
  });
}

const _fixedDate = _FixedDateTime();

class _FixedDateTime implements DateTime {
  const _FixedDateTime();

  @override
  int get year => 2026;
  @override
  int get month => 7;
  @override
  int get day => 15;
  @override
  int get hour => 10;
  @override
  int get minute => 30;
  @override
  int get second => 0;
  @override
  int get millisecond => 0;
  @override
  int get microsecond => 0;

  @override
  String toIso8601String() => '2026-07-15T10:30:00.000';
  @override
  String toString() => toIso8601String();
  @override
  DateTime toLocal() => DateTime(2026, 7, 15, 10, 30);
  @override
  DateTime toUtc() => DateTime.utc(2026, 7, 15, 10, 30);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
