import 'package:finora/features/budget/domain/entities/budget.dart';

class BudgetModel extends Budget {
  const BudgetModel({
    required super.id,
    required super.userId,
    required super.categoryId,
    required super.month,
    required super.year,
    required super.amount,
  });

  factory BudgetModel.fromEntity(Budget entity) {
    return BudgetModel(
      id: entity.id,
      userId: entity.userId,
      categoryId: entity.categoryId,
      month: entity.month,
      year: entity.year,
      amount: entity.amount,
    );
  }

  Budget toEntity() {
    return Budget(
      id: id,
      userId: userId,
      categoryId: categoryId,
      month: month,
      year: year,
      amount: amount,
    );
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      categoryId: map['category_id'] as String,
      month: map['month'] as int,
      year: map['year'] as int,
      amount: double.parse(map['amount'].toString()),
    );
  }

  Map<String, dynamic> toCache() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'month': month,
      'year': year,
      'amount': amount,
    };
  }

  Map<String, dynamic> toInsert() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'month': month,
      'year': year,
      'amount': amount,
    };
  }
}
