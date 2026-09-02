import 'package:equatable/equatable.dart';

/// Time granularity for analytics views.
enum AnalyticsPeriod {
  daily,
  weekly,
  monthly;

  String get label => switch (this) {
        AnalyticsPeriod.daily => 'Daily',
        AnalyticsPeriod.weekly => 'Weekly',
        AnalyticsPeriod.monthly => 'Monthly',
      };
}

/// A single data point for the bar chart (e.g. one day or one week).
class BarChartEntry extends Equatable {
  const BarChartEntry({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;

  double get net => income - expense;

  @override
  List<Object?> get props => [label, income, expense];
}

/// A single slice for the pie chart.
class PieChartEntry extends Equatable {
  const PieChartEntry({
    required this.categoryId,
    required this.categoryName,
    required this.color,
    required this.amount,
    required this.percentage,
  });

  final String categoryId;
  final String categoryName;
  final String color;
  final double amount;
  final double percentage;

  @override
  List<Object?> get props =>
      [categoryId, categoryName, color, amount, percentage];
}

/// The full analytics state consumed by the UI.
class AnalyticsSummary extends Equatable {
  const AnalyticsSummary({
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.savings,
    required this.barData,
    required this.pieData,
    required this.topCategories,
  });

  const AnalyticsSummary.empty()
      : period = AnalyticsPeriod.monthly,
        totalIncome = 0,
        totalExpense = 0,
        savings = 0,
        barData = const [],
        pieData = const [],
        topCategories = const [];

  final AnalyticsPeriod period;
  final double totalIncome;
  final double totalExpense;
  final double savings;
  final List<BarChartEntry> barData;
  final List<PieChartEntry> pieData;
  final List<PieChartEntry> topCategories;

  double get savingsRate =>
      totalIncome <= 0 ? 0 : (savings / totalIncome * 100).clamp(0, 100);

  @override
  List<Object?> get props => [
        period,
        totalIncome,
        totalExpense,
        savings,
        barData,
        pieData,
        topCategories,
      ];
}
