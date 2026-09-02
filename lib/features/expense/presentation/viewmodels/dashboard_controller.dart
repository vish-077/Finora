import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/expense/domain/entities/dashboard_summary.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';

part 'dashboard_controller.g.dart';

@riverpod
class DashboardController extends _$DashboardController {
  @override
  FutureOr<DashboardSummary> build() {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    if (expensesAsync.hasValue && categoriesAsync.hasValue) {
      final expenses = expensesAsync.value!;
      final categories = categoriesAsync.value!;
      final useCase = ref.read(getDashboardSummaryUseCaseProvider);
      return useCase.compute(expenses, categories, DateTime.now());
    }

    return _load();
  }

  Future<DashboardSummary> _load() async {
    final result = await ref.read(getDashboardSummaryUseCaseProvider)();
    return result.fold((failure) => throw failure, (summary) => summary);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
