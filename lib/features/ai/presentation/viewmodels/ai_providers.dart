import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/features/ai/domain/repositories/insight_repository.dart';
import 'package:finora/features/ai/domain/use_cases/insight_use_cases.dart';

part 'ai_providers.g.dart';

@riverpod
InsightRepository insightRepository(InsightRepositoryRef ref) =>
    sl<InsightRepository>();

@riverpod
GetFinancialHealthUseCase getFinancialHealthUseCase(
        GetFinancialHealthUseCaseRef ref) =>
    sl<GetFinancialHealthUseCase>();

@riverpod
GetInsightsUseCase getInsightsUseCase(GetInsightsUseCaseRef ref) =>
    sl<GetInsightsUseCase>();
