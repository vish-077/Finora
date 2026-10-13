import 'dart:convert';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/features/budget/data/models/budget_model.dart';

// ── Local ─────────────────────────────────────────────────────────────────────
abstract interface class BudgetLocalSource {
  List<BudgetModel> readBudgets(int month, int year);
  Future<void> upsert(BudgetModel budget);
  Future<void> delete(String id);
}

class BudgetLocalSourceImpl implements BudgetLocalSource {
  BudgetLocalSourceImpl(this._box);

  final SqlBox _box;

  @override
  List<BudgetModel> readBudgets(int month, int year) {
    final result = <BudgetModel>[];
    for (final value in _box.values) {
      if (value is! String) continue;
      try {
        final model =
            BudgetModel.fromMap(jsonDecode(value) as Map<String, dynamic>);
        if (model.month == month && model.year == year) {
          result.add(model);
        }
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  @override
  Future<void> upsert(BudgetModel budget) =>
      _box.put(budget.id, jsonEncode(budget.toCache()));

  @override
  Future<void> delete(String id) => _box.delete(id);
}
