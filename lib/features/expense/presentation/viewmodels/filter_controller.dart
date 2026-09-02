import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/shared/enums/transaction_type.dart';

part 'filter_controller.g.dart';

/// Holds the active [ExpenseFilter] for the transaction list & search.
@riverpod
class FilterController extends _$FilterController {
  @override
  ExpenseFilter build() => const ExpenseFilter();

  void setPreset(DateRangePreset preset) =>
      state = state.copyWith(preset: preset);

  void setCustomRange(DateTime start, DateTime end) => state = state.copyWith(
        preset: DateRangePreset.custom,
        customStart: start,
        customEnd: end,
      );

  void setCategory(String? categoryId) => state = categoryId == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(categoryId: categoryId);

  void setPaymentMethod(PaymentMethod? method) => state = method == null
      ? state.copyWith(clearPaymentMethod: true)
      : state.copyWith(paymentMethod: method);

  void setTransactionType(TransactionType? type) => state = type == null
      ? state.copyWith(clearTransactionType: true)
      : state.copyWith(transactionType: type);

  void setQuery(String query) => state = state.copyWith(query: query);

  void clear() => state = const ExpenseFilter();
}
