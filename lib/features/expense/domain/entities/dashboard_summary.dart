import 'package:equatable/equatable.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';

/// A category slice of spending, for the dashboard breakdown chart.
class CategorySpend extends Equatable {
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.color,
    required this.total,
  });

  final String categoryId;
  final String categoryName;
  final String color;
  final double total;

  @override
  List<Object?> get props => [categoryId, categoryName, color, total];
}

/// Aggregated figures shown on the dashboard.
class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.todayIncome,
    required this.todayExpense,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.savings,
    required this.recentTransactions,
    required this.byCategory,
  });

  const DashboardSummary.empty()
      : totalBalance = 0,
        totalIncome = 0,
        totalExpense = 0,
        todayIncome = 0,
        todayExpense = 0,
        monthlyIncome = 0,
        monthlyExpense = 0,
        savings = 0,
        recentTransactions = const [],
        byCategory = const [];

  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final double todayIncome;
  final double todayExpense;
  final double monthlyIncome;
  final double monthlyExpense;
  final double savings;
  final List<Expense> recentTransactions;
  final List<CategorySpend> byCategory;

  @override
  List<Object?> get props => [
        totalBalance,
        totalIncome,
        totalExpense,
        todayIncome,
        todayExpense,
        monthlyIncome,
        monthlyExpense,
        savings,
        recentTransactions,
        byCategory,
      ];
}
