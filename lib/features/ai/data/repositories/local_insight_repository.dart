import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/ai/domain/entities/ai_entities.dart';
import 'package:finora/features/ai/domain/repositories/insight_repository.dart';
import 'package:finora/features/expense/data/models/expense_model.dart';
import 'package:finora/features/budget/data/models/budget_model.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class LocalInsightRepositoryImpl implements InsightRepository {
  LocalInsightRepositoryImpl({
    required this.transactionBox,
    required this.budgetBox,
  });

  final SqlBox transactionBox;
  final SqlBox budgetBox;

  @override
  Future<Either<Failure, FinancialHealth>> getFinancialHealth(String userId) async {
    try {
      final now = DateTime.now();
      
      // Calculate this month's income and expense
      double currentIncome = 0;
      double currentExpense = 0;
      
      final transactions = _rows(transactionBox).map(ExpenseModel.fromMap)
          .where((e) => e.userId == userId && e.transactionDate.month == now.month && e.transactionDate.year == now.year);
          
      for (final t in transactions) {
        if (t.transactionType == TransactionType.income) {
          currentIncome += t.amount;
        } else {
          currentExpense += t.amount;
        }
      }

      final monthTransactions = transactions.toList();

      // ── Budget adherence ────────────────────────────────────────────────
      // Only spending in *budgeted* categories is compared against the budget
      // total; charging unbudgeted spend against budgeted categories made the
      // figure look far worse than reality.
      double? budgetAdherence;
      final budgets = _rows(budgetBox)
          .map(BudgetModel.fromMap)
          .where((b) =>
              b.userId == userId && b.month == now.month && b.year == now.year)
          .toList();

      final totalBudget = budgets.fold(0.0, (sum, b) => sum + b.amount);
      if (budgets.isNotEmpty && totalBudget > 0) {
        final budgetedCategoryIds =
            budgets.map((b) => b.categoryId).whereType<String>().toSet();
        final budgetedSpend = monthTransactions
            .where((t) =>
                t.transactionType == TransactionType.expense &&
                t.categoryId != null &&
                budgetedCategoryIds.contains(t.categoryId))
            .fold(0.0, (sum, t) => sum + t.amount);

        budgetAdherence =
            ((totalBudget - budgetedSpend) / totalBudget).clamp(0.0, 1.0);
      }

      // ── Savings ratio ───────────────────────────────────────────────────
      // Null, not zero, when there is no income to measure against.
      double? savingsRatio;
      if (currentIncome > 0) {
        savingsRatio =
            ((currentIncome - currentExpense) / currentIncome).clamp(0.0, 1.0);
      }

      // ── Weighted score over measurable factors only ─────────────────────
      final factors = <HealthFactor>[];

      if (savingsRatio != null) {
        // 20% of income kept counts as full marks.
        factors.add(HealthFactor(
          label: 'Savings rate',
          detail: '${(savingsRatio * 100).toStringAsFixed(0)}% of income kept',
          weight: 40,
          value: (savingsRatio / 0.2).clamp(0.0, 1.0),
        ));

        // Spend-to-income, graded continuously so the score is not quantised:
        // at or under 70% of income scores full, 100%+ scores zero.
        final spendRatio = currentExpense / currentIncome;
        factors.add(HealthFactor(
          label: 'Spending vs income',
          detail: '${(spendRatio * 100).toStringAsFixed(0)}% of income spent',
          weight: 25,
          value: ((1.0 - spendRatio) / 0.3).clamp(0.0, 1.0),
        ));
      }

      if (budgetAdherence != null) {
        factors.add(HealthFactor(
          label: 'Budget adherence',
          detail: budgetAdherence >= 1
              ? 'Within budget'
              : '${(budgetAdherence * 100).toStringAsFixed(0)}% of budget left',
          weight: 25,
          value: budgetAdherence,
        ));
      }

      if (monthTransactions.isNotEmpty) {
        // Rewards consistent logging: roughly one entry every three days of the
        // month so far is treated as fully tracked.
        final daysElapsed = now.day;
        final target = (daysElapsed / 3).clamp(1.0, 10.0);
        factors.add(HealthFactor(
          label: 'Tracking consistency',
          detail: '${monthTransactions.length} entries this month',
          weight: 10,
          value: (monthTransactions.length / target).clamp(0.0, 1.0),
        ));
      }

      // Normalise by the weight actually available, so a missing factor neither
      // inflates nor deflates the result.
      final int totalScore;
      if (factors.isEmpty) {
        totalScore = 0;
      } else {
        final weightSum = factors.fold(0.0, (sum, f) => sum + f.weight);
        final weighted =
            factors.fold(0.0, (sum, f) => sum + f.value * f.weight);
        totalScore = (weighted / weightSum * 100).round().clamp(0, 100);
      }

      final HealthStatus status;
      if (factors.isEmpty) {
        status = HealthStatus.average; // nothing measured yet
      } else if (totalScore >= 80) {
        status = HealthStatus.excellent;
      } else if (totalScore >= 60) {
        status = HealthStatus.good;
      } else if (totalScore >= 40) {
        status = HealthStatus.average;
      } else {
        status = HealthStatus.poor;
      }

      return Right(FinancialHealth(
        score: totalScore,
        status: status,
        savingsRatio: savingsRatio,
        budgetAdherence: budgetAdherence,
        factors: factors,
        monthlyIncome: currentIncome,
        monthlyExpense: currentExpense,
        transactionCount: monthTransactions.length,
      ));
    } catch (e) {
      return Left(LocalFailure('Failed to calculate health score: $e'));
    }
  }

  @override
  Future<Either<Failure, List<FinancialInsight>>> getInsights(String userId) async {
    try {
      final now = DateTime.now();
      final insights = <FinancialInsight>[];
      
      // Gather some simple offline heuristics
      double currentIncome = 0;
      double currentExpense = 0;
      
      final transactions = _rows(transactionBox).map(ExpenseModel.fromMap)
          .where((e) => e.userId == userId && e.transactionDate.month == now.month && e.transactionDate.year == now.year);
          
      for (final t in transactions) {
        if (t.transactionType == TransactionType.income) {
          currentIncome += t.amount;
        } else {
          currentExpense += t.amount;
        }
      }
      
      if (currentExpense > currentIncome && currentIncome > 0) {
        insights.add(
          FinancialInsight(
            id: 'over_spending_${now.millisecondsSinceEpoch}',
            title: 'Spending Exceeds Income',
            description: 'You have spent more than you earned this month. Try to cut back on non-essentials.',
            severity: InsightSeverity.warning,
          ),
        );
      } else if (currentIncome > 0 && (currentIncome - currentExpense) > (currentIncome * 0.3)) {
        insights.add(
          FinancialInsight(
            id: 'good_saving_${now.millisecondsSinceEpoch}',
            title: 'Excellent Savings Rate',
            description: 'You have saved over 30% of your income this month! Keep up the great work.',
            severity: InsightSeverity.success,
          ),
        );
      }
      
      // Default info insight if none triggered
      if (insights.isEmpty) {
        insights.add(
          FinancialInsight(
            id: 'general_info_${now.millisecondsSinceEpoch}',
            title: 'Track Your Budgets',
            description: 'Setting up category budgets is the best way to control spending.',
            severity: InsightSeverity.info,
            actionRoute: '/budgets',
          ),
        );
      }

      return Right(insights);
    } catch (e) {
      return Left(LocalFailure('Failed to generate insights: $e'));
    }
  }

  /// Boxes cache rows as JSON strings (see the feature local sources), so a
  /// raw `box.values` read yields nothing until they are decoded.
  Iterable<Map<String, dynamic>> _rows(SqlBox box) sync* {
    for (final value in box.values) {
      if (value is! String) continue;
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) yield Map<String, dynamic>.from(decoded);
      } on FormatException {
        continue;
      }
    }
  }
}
