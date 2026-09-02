import 'package:collection/collection.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class GetAnalyticsUseCase {
  const GetAnalyticsUseCase(this._expenseRepo, this._categoryRepo);

  final ExpenseRepository _expenseRepo;
  final CategoryRepository _categoryRepo;

  Future<Either<Failure, AnalyticsSummary>> call({
    AnalyticsPeriod period = AnalyticsPeriod.monthly,
    DateTime? now,
  }) async {
    final expensesResult = await _expenseRepo.getExpenses();
    return expensesResult.fold(
      left,
      (expenses) async {
        final categoriesResult = await _categoryRepo.getCategories();
        final categories = categoriesResult.getRight().toNullable() ?? [];
        return right(_compute(expenses, categories, period, now ?? DateTime.now()));
      },
    );
  }

  AnalyticsSummary _compute(
    List<Expense> allExpenses,
    List<Category> categories,
    AnalyticsPeriod period,
    DateTime now,
  ) {
    // Filter expenses within the selected period range
    final range = _periodRange(period, now);
    final filtered = allExpenses.where((e) {
      return !e.transactionDate.isBefore(range.start) &&
          e.transactionDate.isBefore(range.end);
    }).toList();

    // Compute totals
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    final categoryTotals = <String, double>{};

    for (final e in filtered) {
      if (e.isIncome) {
        totalIncome += e.amount;
      } else if (e.isExpense) {
        totalExpense += e.amount;
        final key = e.categoryId ?? '_uncategorized';
        categoryTotals[key] = (categoryTotals[key] ?? 0) + e.amount;
      }
    }

    final savings = totalIncome - totalExpense;

    // Build pie chart data
    final categoryById = {for (final c in categories) c.id: c};
    final totalForPie = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final pieData = categoryTotals.entries.map((entry) {
      final cat = categoryById[entry.key];
      return PieChartEntry(
        categoryId: entry.key,
        categoryName: cat?.name ?? 'Uncategorized',
        color: cat?.color ?? '#95A5A6',
        amount: entry.value,
        percentage: totalForPie > 0 ? (entry.value / totalForPie * 100) : 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Build bar chart data
    final barData = _buildBarData(filtered, period, range);

    return AnalyticsSummary(
      period: period,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savings: savings,
      barData: barData,
      pieData: pieData,
      topCategories: pieData.take(5).toList(),
    );
  }

  ({DateTime start, DateTime end}) _periodRange(AnalyticsPeriod period, DateTime now) {
    switch (period) {
      case AnalyticsPeriod.daily:
        // Last 7 days
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
        return (start: start, end: end);
      case AnalyticsPeriod.weekly:
        // Last 4 weeks
        final start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 27));
        final end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
        return (start: start, end: end);
      case AnalyticsPeriod.monthly:
        // Last 6 months
        final start = DateTime(now.year, now.month - 5);
        final end = DateTime(now.year, now.month + 1);
        return (start: start, end: end);
    }
  }

  List<BarChartEntry> _buildBarData(
    List<Expense> filtered,
    AnalyticsPeriod period,
    ({DateTime start, DateTime end}) range,
  ) {
    switch (period) {
      case AnalyticsPeriod.daily:
        return _dailyBars(filtered, range);
      case AnalyticsPeriod.weekly:
        return _weeklyBars(filtered, range);
      case AnalyticsPeriod.monthly:
        return _monthlyBars(filtered, range);
    }
  }

  List<BarChartEntry> _dailyBars(
    List<Expense> filtered,
    ({DateTime start, DateTime end}) range,
  ) {
    final bars = <BarChartEntry>[];
    var cursor = range.start;
    while (cursor.isBefore(range.end)) {
      final dayStart = DateTime(cursor.year, cursor.month, cursor.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dayExpenses = filtered.where((e) =>
          !e.transactionDate.isBefore(dayStart) &&
          e.transactionDate.isBefore(dayEnd));
      bars.add(BarChartEntry(
        label: DateFormat('E').format(cursor),
        income: dayExpenses.where((e) => e.isIncome).fold(0.0, (s, e) => s + e.amount),
        expense: dayExpenses.where((e) => e.isExpense).fold(0.0, (s, e) => s + e.amount),
      ));
      cursor = dayEnd;
    }
    return bars;
  }

  List<BarChartEntry> _weeklyBars(
    List<Expense> filtered,
    ({DateTime start, DateTime end}) range,
  ) {
    final bars = <BarChartEntry>[];
    var cursor = range.start;
    var weekNum = 1;
    while (cursor.isBefore(range.end)) {
      final weekEnd = cursor.add(const Duration(days: 7));
      final clampedEnd = weekEnd.isAfter(range.end) ? range.end : weekEnd;
      final weekExpenses = filtered.where((e) =>
          !e.transactionDate.isBefore(cursor) &&
          e.transactionDate.isBefore(clampedEnd));
      bars.add(BarChartEntry(
        label: 'W$weekNum',
        income: weekExpenses.where((e) => e.isIncome).fold(0.0, (s, e) => s + e.amount),
        expense: weekExpenses.where((e) => e.isExpense).fold(0.0, (s, e) => s + e.amount),
      ));
      cursor = weekEnd;
      weekNum++;
    }
    return bars;
  }

  List<BarChartEntry> _monthlyBars(
    List<Expense> filtered,
    ({DateTime start, DateTime end}) range,
  ) {
    final bars = <BarChartEntry>[];
    var cursor = range.start;
    while (cursor.isBefore(range.end)) {
      final monthStart = DateTime(cursor.year, cursor.month);
      final monthEnd = DateTime(cursor.year, cursor.month + 1);
      final monthExpenses = filtered.where((e) =>
          !e.transactionDate.isBefore(monthStart) &&
          e.transactionDate.isBefore(monthEnd));
      bars.add(BarChartEntry(
        label: DateFormat('MMM').format(cursor),
        income: monthExpenses.where((e) => e.isIncome).fold(0.0, (s, e) => s + e.amount),
        expense: monthExpenses.where((e) => e.isExpense).fold(0.0, (s, e) => s + e.amount),
      ));
      cursor = monthEnd;
    }
    return bars;
  }
}
