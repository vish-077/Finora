import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/ai/domain/entities/ai_entities.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_providers.dart';

import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_providers.dart';

part 'ai_dashboard_controller.g.dart';

class AiDashboardState {
  const AiDashboardState({
    required this.health,
    required this.insights,
  });

  final FinancialHealth? health;
  final List<FinancialInsight> insights;
}

@riverpod
class AiDashboardController extends _$AiDashboardController {
  @override
  FutureOr<AiDashboardState> build() async {
    // Register dependency on the reactive database streams
    ref.watch(expensesStreamProvider);
    final now = DateTime.now();
    ref.watch(budgetsStreamProvider(month: now.month, year: now.year));

    return _fetchData();
  }

  String get _userId =>
      ref.read(authControllerProvider).user?.id ?? 'local-user';

  Future<AiDashboardState> _fetchData() async {
    final healthUseCase = ref.watch(getFinancialHealthUseCaseProvider);
    final insightsUseCase = ref.watch(getInsightsUseCaseProvider);

    final healthResult = await healthUseCase(_userId);
    final insightsResult = await insightsUseCase(_userId);

    return AiDashboardState(
      health: healthResult.fold((_) => null, (h) => h),
      insights: insightsResult.fold((_) => [], (i) => i),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchData);
  }
}
