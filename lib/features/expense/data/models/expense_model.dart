import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class ExpenseModel extends Expense {
  const ExpenseModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.amount,
    required super.transactionType,
    required super.paymentMethod,
    required super.transactionDate,
    super.categoryId,
    super.accountId,
    super.notes,
    super.createdAt,
    super.updatedAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) => ExpenseModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: (map['title'] as String?) ?? '',
        amount: _toDouble(map['amount']),
        categoryId: map['category_id'] as String?,
        accountId: map['account_id'] as String?,
        paymentMethod: PaymentMethod.fromWire(map['payment_method'] as String?),
        transactionType:
            TransactionTypeWire.fromWire(map['transaction_type'] as String?),
        notes: map['notes'] as String?,
        transactionDate:
            _date(map['transaction_date']) ?? DateTime.now(),
        createdAt: _date(map['created_at']),
        updatedAt: _date(map['updated_at']),
      );

  factory ExpenseModel.fromEntity(Expense e) => ExpenseModel(
        id: e.id,
        userId: e.userId,
        title: e.title,
        amount: e.amount,
        categoryId: e.categoryId,
        accountId: e.accountId,
        paymentMethod: e.paymentMethod,
        transactionType: e.transactionType,
        notes: e.notes,
        transactionDate: e.transactionDate,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  /// Payload for insert/update. Excludes id so the DB can generate it on insert;
  /// callers include it explicitly for updates.
  Map<String, dynamic> toInsert() => <String, dynamic>{
        'user_id': userId,
        'title': title,
        'amount': amount,
        'category_id': categoryId,
        'account_id': accountId,
        'payment_method': paymentMethod.wire,
        'transaction_type': transactionType.wire,
        'notes': notes,
        'transaction_date': transactionDate.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toCache() => <String, dynamic>{
        'id': id,
        ...toInsert(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
}
