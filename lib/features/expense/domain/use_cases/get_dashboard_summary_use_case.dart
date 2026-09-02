import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/entities/dashboard_summary.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

class GetDashboardSummaryUseCase {
  const GetDashboardSummaryUseCase(this._expenseRepo, this._categoryRepo);

  final ExpenseRepository _expenseRepo;
  final CategoryRepository _categoryRepo;

  Future<Either<Failure, DashboardSummary>> call({DateTime? now}) async {
    final expensesResult = await _expenseRepo.getExpenses();
    return expensesResult.fold(
      left,
      (expenses) async {
        final categoriesResult = await _categoryRepo.getCategories();
        final categories = categoriesResult.getRight().toNullable() ?? [];
        return right(compute(expenses, categories, now ?? DateTime.now()));
      },
    );
  }

  DashboardSummary compute(
    List<Expense> expenses,
    List<Category> categories,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);

    var totalBalance = 0.0;
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    var todayIncome = 0.0;
    var todayExpense = 0.0;
    var monthlyIncome = 0.0;
    var monthlyExpense = 0.0;
    final categoryTotals = <String, double>{};

    for (final e in expenses) {
      totalBalance += e.signedAmount;

      if (e.isExpense) {
        totalExpense += e.amount;
        if (!e.transactionDate.isBefore(today)) {
          todayExpense += e.amount;
        }
        if (!e.transactionDate.isBefore(monthStart)) {
          monthlyExpense += e.amount;
          final key = e.categoryId ?? '_uncategorized';
          categoryTotals[key] = (categoryTotals[key] ?? 0) + e.amount;
        }
      } else if (e.isIncome) {
        totalIncome += e.amount;
        if (!e.transactionDate.isBefore(today)) {
          todayIncome += e.amount;
        }
        if (!e.transactionDate.isBefore(monthStart)) {
          monthlyIncome += e.amount;
        }
      }
    }

    final savings = totalIncome - totalExpense;

    final categoryById = {for (final c in categories) c.id: c};
    final byCategory = categoryTotals.entries.map((entry) {
      final cat = categoryById[entry.key];
      return CategorySpend(
        categoryId: entry.key,
        categoryName: cat?.name ?? 'Uncategorized',
        color: cat?.color ?? '#95A5A6',
        total: entry.value,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final recent = [...expenses]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    return DashboardSummary(
      totalBalance: totalBalance,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      todayIncome: todayIncome,
      todayExpense: todayExpense,
      monthlyIncome: monthlyIncome,
      monthlyExpense: monthlyExpense,
      savings: savings,
      recentTransactions: recent.take(5).toList(),
      byCategory: byCategory,
    );
  }
}
