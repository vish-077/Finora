import 'package:equatable/equatable.dart';
import 'package:finora/shared/enums/transaction_type.dart';

enum DateRangePreset {
  all,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  custom;

  String get label => switch (this) {
        DateRangePreset.all => 'All time',
        DateRangePreset.today => 'Today',
        DateRangePreset.yesterday => 'Yesterday',
        DateRangePreset.thisWeek => 'This week',
        DateRangePreset.thisMonth => 'This month',
        DateRangePreset.lastMonth => 'Last month',
        DateRangePreset.custom => 'Custom',
      };
}

/// Immutable filter/search criteria for the transaction list.
class ExpenseFilter extends Equatable {
  const ExpenseFilter({
    this.preset = DateRangePreset.all,
    this.customStart,
    this.customEnd,
    this.categoryId,
    this.paymentMethod,
    this.transactionType,
    this.query = '',
  });

  final DateRangePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? categoryId;
  final PaymentMethod? paymentMethod;
  final TransactionType? transactionType;
  final String query;

  bool get isActive =>
      preset != DateRangePreset.all ||
      categoryId != null ||
      paymentMethod != null ||
      transactionType != null ||
      query.trim().isNotEmpty;

  /// Resolves [preset] into a concrete [start, end) date window.
  ({DateTime? start, DateTime? end}) resolveRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case DateRangePreset.all:
        return (start: null, end: null);
      case DateRangePreset.today:
        return (start: today, end: today.add(const Duration(days: 1)));
      case DateRangePreset.yesterday:
        return (
          start: today.subtract(const Duration(days: 1)),
          end: today,
        );
      case DateRangePreset.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (start: monday, end: monday.add(const Duration(days: 7)));
      case DateRangePreset.thisMonth:
        return (
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        );
      case DateRangePreset.lastMonth:
        return (
          start: DateTime(now.year, now.month - 1),
          end: DateTime(now.year, now.month),
        );
      case DateRangePreset.custom:
        return (start: customStart, end: customEnd);
    }
  }

  ExpenseFilter copyWith({
    DateRangePreset? preset,
    DateTime? customStart,
    DateTime? customEnd,
    String? categoryId,
    PaymentMethod? paymentMethod,
    TransactionType? transactionType,
    String? query,
    bool clearCategory = false,
    bool clearPaymentMethod = false,
    bool clearTransactionType = false,
  }) =>
      ExpenseFilter(
        preset: preset ?? this.preset,
        customStart: customStart ?? this.customStart,
        customEnd: customEnd ?? this.customEnd,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        paymentMethod:
            clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
        transactionType: clearTransactionType
            ? null
            : (transactionType ?? this.transactionType),
        query: query ?? this.query,
      );

  @override
  List<Object?> get props => [
        preset,
        customStart,
        customEnd,
        categoryId,
        paymentMethod,
        transactionType,
        query,
      ];
}
