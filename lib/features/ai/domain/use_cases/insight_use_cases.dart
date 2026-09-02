import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/ai/domain/entities/ai_entities.dart';
import 'package:finora/features/ai/domain/repositories/insight_repository.dart';

class GetFinancialHealthUseCase {
  const GetFinancialHealthUseCase(this._repository);
  final InsightRepository _repository;

  Future<Either<Failure, FinancialHealth>> call(String userId) =>
      _repository.getFinancialHealth(userId);
}

class GetInsightsUseCase {
  const GetInsightsUseCase(this._repository);
  final InsightRepository _repository;

  Future<Either<Failure, List<FinancialInsight>>> call(String userId) =>
      _repository.getInsights(userId);
}
