import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/shared/enums/transaction_type.dart';

void main() {
  group('ExpenseFilter', () {
    test('should be inactive when defaults', () {
      const filter = ExpenseFilter();
      expect(filter.isActive, isFalse);
      expect(filter.query, isEmpty);
      expect(filter.preset, DateRangePreset.all);
    });

    test('should be active when query is not empty', () {
      const filter = ExpenseFilter(query: 'food');
      expect(filter.isActive, isTrue);
    });

    test('should be active when category is set', () {
      const filter = ExpenseFilter(categoryId: 'cat-1');
      expect(filter.isActive, isTrue);
    });

    test('should be active when payment method is set', () {
      const filter = ExpenseFilter(paymentMethod: PaymentMethod.upi);
      expect(filter.isActive, isTrue);
    });

    test('should be active when transaction type is set', () {
      const filter = ExpenseFilter(
        transactionType: TransactionType.expense,
      );
      expect(filter.isActive, isTrue);
    });

    test('should be active when preset is not all', () {
      const filter = ExpenseFilter(preset: DateRangePreset.today);
      expect(filter.isActive, isTrue);
    });

    test('copyWith should clear category when clearCategory is true', () {
      const filter = ExpenseFilter(categoryId: 'cat-1');
      final updated = filter.copyWith(clearCategory: true);
      expect(updated.categoryId, isNull);
    });

    test('copyWith should clear paymentMethod when clearPaymentMethod is true',
        () {
      const filter = ExpenseFilter(paymentMethod: PaymentMethod.creditCard);
      final updated = filter.copyWith(clearPaymentMethod: true);
      expect(updated.paymentMethod, isNull);
    });

    test('copyWith should clear transactionType when clearTransactionType is true',
        () {
      const filter = ExpenseFilter(
        transactionType: TransactionType.expense,
      );
      final updated = filter.copyWith(clearTransactionType: true);
      expect(updated.transactionType, isNull);
    });

    group('resolveRange', () {
      final now = DateTime(2026, 7, 15, 14, 30); // Wednesday

      test('all returns null start and end', () {
        const filter = ExpenseFilter(preset: DateRangePreset.all);
        final range = filter.resolveRange(now);
        expect(range.start, isNull);
        expect(range.end, isNull);
      });

      test('today returns correct range', () {
        const filter = ExpenseFilter(preset: DateRangePreset.today);
        final range = filter.resolveRange(now);
        expect(range.start, DateTime(2026, 7, 15));
        expect(range.end, DateTime(2026, 7, 16));
      });

      test('yesterday returns correct range', () {
        const filter = ExpenseFilter(preset: DateRangePreset.yesterday);
        final range = filter.resolveRange(now);
        expect(range.start, DateTime(2026, 7, 14));
        expect(range.end, DateTime(2026, 7, 15));
      });

      test('thisMonth returns correct range', () {
        const filter = ExpenseFilter(preset: DateRangePreset.thisMonth);
        final range = filter.resolveRange(now);
        expect(range.start, DateTime(2026, 7));
        expect(range.end, DateTime(2026, 8));
      });
    });
  });
}
