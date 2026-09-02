import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';

void main() {
  group('AnalyticsSummary', () {
    test('empty constructor has zero values', () {
      const summary = AnalyticsSummary.empty();
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
      expect(summary.savings, 0);
      expect(summary.barData, isEmpty);
      expect(summary.pieData, isEmpty);
      expect(summary.topCategories, isEmpty);
      expect(summary.period, AnalyticsPeriod.monthly);
    });

    test('savingsRate calculates correctly', () {
      const summary = AnalyticsSummary(
        period: AnalyticsPeriod.monthly,
        totalIncome: 50000,
        totalExpense: 30000,
        savings: 20000,
        barData: [],
        pieData: [],
        topCategories: [],
      );
      expect(summary.savingsRate, 40.0);
    });

    test('savingsRate is 0 when income is 0', () {
      const summary = AnalyticsSummary(
        period: AnalyticsPeriod.monthly,
        totalIncome: 0,
        totalExpense: 500,
        savings: -500,
        barData: [],
        pieData: [],
        topCategories: [],
      );
      expect(summary.savingsRate, 0);
    });

    test('savingsRate clamps to 100 when savings > income (edge case)', () {
      const summary = AnalyticsSummary(
        period: AnalyticsPeriod.monthly,
        totalIncome: 100,
        totalExpense: 0,
        savings: 100,
        barData: [],
        pieData: [],
        topCategories: [],
      );
      expect(summary.savingsRate, 100.0);
    });
  });

  group('BarChartEntry', () {
    test('net calculates income minus expense', () {
      const entry = BarChartEntry(
        label: 'Mon',
        income: 1000,
        expense: 600,
      );
      expect(entry.net, 400);
    });

    test('net is negative when expense exceeds income', () {
      const entry = BarChartEntry(
        label: 'Tue',
        income: 200,
        expense: 500,
      );
      expect(entry.net, -300);
    });
  });

  group('PieChartEntry', () {
    test('equatable works', () {
      const a = PieChartEntry(
        categoryId: 'c1',
        categoryName: 'Food',
        color: '#FF5722',
        amount: 500,
        percentage: 50,
      );
      const b = PieChartEntry(
        categoryId: 'c1',
        categoryName: 'Food',
        color: '#FF5722',
        amount: 500,
        percentage: 50,
      );
      expect(a, equals(b));
    });
  });

  group('AnalyticsPeriod', () {
    test('labels are correct', () {
      expect(AnalyticsPeriod.daily.label, 'Daily');
      expect(AnalyticsPeriod.weekly.label, 'Weekly');
      expect(AnalyticsPeriod.monthly.label, 'Monthly');
    });
  });
}
