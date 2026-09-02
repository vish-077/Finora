import 'package:equatable/equatable.dart';
import 'package:finora/shared/enums/transaction_type.dart';

/// A single expense/income transaction.
class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.transactionType,
    required this.paymentMethod,
    required this.transactionDate,
    this.categoryId,
    this.accountId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final double amount;
  final String? categoryId;
  final String? accountId;
  final PaymentMethod paymentMethod;
  final TransactionType transactionType;
  final String? notes;
  final DateTime transactionDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isIncome => transactionType == TransactionType.income;
  bool get isExpense => transactionType == TransactionType.expense;

  /// Signed amount: positive for income, negative for expense.
  double get signedAmount => isIncome ? amount : -amount;

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? accountId,
    PaymentMethod? paymentMethod,
    TransactionType? transactionType,
    String? notes,
    DateTime? transactionDate,
  }) =>
      Expense(
        id: id ?? this.id,
        userId: userId,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        transactionType: transactionType ?? this.transactionType,
        notes: notes ?? this.notes,
        transactionDate: transactionDate ?? this.transactionDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        amount,
        categoryId,
        accountId,
        paymentMethod,
        transactionType,
        notes,
        transactionDate,
      ];
}
