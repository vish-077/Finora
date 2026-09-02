import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/ai/domain/entities/ai_entities.dart';

abstract class InsightRepository {
  /// Analyzes local offline data to generate a user's financial health score
  Future<Either<Failure, FinancialHealth>> getFinancialHealth(String userId);

  /// Generates dynamic offline insights based on spending behavior and budgets
  Future<Either<Failure, List<FinancialInsight>>> getInsights(String userId);
}
