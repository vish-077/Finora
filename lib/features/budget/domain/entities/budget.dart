import 'package:equatable/equatable.dart';

enum BudgetStatus {
  safe,
  warning,
  overLimit;
}

class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.amount,
  });

  final String id;
  final String userId;
  final String categoryId;
  final int month;
  final int year;
  final double amount;

  Budget copyWith({
    String? id,
    String? userId,
    String? categoryId,
    int? month,
    int? year,
    double? amount,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      year: year ?? this.year,
      amount: amount ?? this.amount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        categoryId,
        month,
        year,
        amount,
      ];
}

/// Helper entity to pass progress data to the UI.
/// Spent amount is calculated dynamically based on expenses.
class BudgetProgress extends Equatable {
  const BudgetProgress({
    required this.budget,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.spent,
  });

  final Budget budget;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final double spent;

  double get remaining => budget.amount - spent;
  double get percentage => budget.amount > 0 ? (spent / budget.amount) : 0.0;

  BudgetStatus get status {
    final p = percentage;
    if (p >= 1.0) return BudgetStatus.overLimit;
    if (p >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  @override
  List<Object?> get props => [
        budget,
        categoryName,
        categoryColor,
        categoryIcon,
        spent,
      ];
}
