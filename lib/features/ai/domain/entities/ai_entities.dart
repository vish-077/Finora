enum InsightSeverity {
  info,
  warning,
  success,
}

class FinancialInsight {
  const FinancialInsight({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String description;
  final InsightSeverity severity;
  final String? actionRoute;
}

enum HealthStatus {
  excellent,
  good,
  average,
  poor,
}

/// One weighted contributor to the health score.
///
/// Factors are only included when the data behind them exists. That is the
/// whole point: an absent factor must not be scored as if it were perfect.
class HealthFactor {
  const HealthFactor({
    required this.label,
    required this.detail,
    required this.weight,
    required this.value,
  });

  final String label;
  final String detail;

  /// Relative importance within the score.
  final double weight;

  /// Normalised 0–1 performance on this factor.
  final double value;

  /// 0–100 for display.
  double get percent => (value * 100).clamp(0, 100);
}

class FinancialHealth {
  const FinancialHealth({
    required this.score,
    required this.status,
    required this.savingsRatio,
    required this.budgetAdherence,
    this.factors = const [],
    this.monthlyIncome = 0,
    this.monthlyExpense = 0,
    this.transactionCount = 0,
  });

  final int score; // 0 to 100

  final HealthStatus status;

  /// Share of income kept this month (0–1), or null when there is no income
  /// recorded — previously this silently read as 0%, which is not the same
  /// thing as "nothing known yet".
  final double? savingsRatio;

  /// How well spending sat inside the budgets (0–1), or null when no budget is
  /// set for the month. It used to default to 1.0 (a perfect score), which
  /// pinned the ring to 50 or 100 for anyone without budgets.
  final double? budgetAdherence;

  /// The factors that actually contributed, for display and transparency.
  final List<HealthFactor> factors;

  final double monthlyIncome;
  final double monthlyExpense;
  final int transactionCount;

  /// True when nothing could be measured, so the UI can prompt for data
  /// instead of showing a meaningless number.
  bool get hasNoData => factors.isEmpty;

  /// Fraction of the full model that could be evaluated (0–1).
  double get dataCoverage {
    if (factors.isEmpty) return 0;
    final measured = factors.fold(0.0, (sum, f) => sum + f.weight);
    return (measured / _totalPossibleWeight).clamp(0.0, 1.0);
  }

  /// Sum of every factor weight the model can award when all data is present.
  static const double _totalPossibleWeight = 100;
}
