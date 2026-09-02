import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/expense/domain/entities/analytics_summary.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';

part 'analytics_controller.g.dart';

/// Selected reporting period. Held outside the controller so it survives the
/// `ref.invalidate` calls fired whenever a transaction is written — otherwise
/// recreating the notifier silently reset the user's choice back to monthly.
final analyticsPeriodProvider =
    StateProvider<AnalyticsPeriod>((ref) => AnalyticsPeriod.monthly);

@riverpod
class AnalyticsController extends _$AnalyticsController {
  @override
  FutureOr<AnalyticsSummary> build() {
    // Watching means a period change re-runs the query on its own.
    final period = ref.watch(analyticsPeriodProvider);
    return _load(period);
  }

  Future<AnalyticsSummary> _load(AnalyticsPeriod period) async {
    final result = await ref.read(getAnalyticsUseCaseProvider)(period: period);
    return result.fold((failure) => throw failure, (summary) => summary);
  }

  void setPeriod(AnalyticsPeriod period) {
    ref.read(analyticsPeriodProvider.notifier).state = period;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _load(ref.read(analyticsPeriodProvider)),
    );
  }
}
