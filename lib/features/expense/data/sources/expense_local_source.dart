import 'dart:convert';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/features/expense/data/models/expense_model.dart';

/// Hive-backed cache for offline-first reads/writes. Each expense is stored as
/// a JSON string keyed by its id.
abstract interface class ExpenseLocalSource {
  List<ExpenseModel> readAll();
  Future<void> upsert(ExpenseModel expense);
  Future<void> replaceAll(List<ExpenseModel> expenses);
  Future<void> delete(String id);
  ExpenseModel? readById(String id);
}

class ExpenseLocalSourceImpl implements ExpenseLocalSource {
  ExpenseLocalSourceImpl(this._box);

  final SqlBox _box;

  @override
  List<ExpenseModel> readAll() {
    final result = <ExpenseModel>[];
    for (final value in _box.values) {
      final model = _decode(value);
      if (model != null) result.add(model);
    }
    result.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return result;
  }

  @override
  ExpenseModel? readById(String id) => _decode(_box.get(id));

  @override
  Future<void> upsert(ExpenseModel expense) =>
      _box.put(expense.id, jsonEncode(expense.toCache()));

  @override
  Future<void> replaceAll(List<ExpenseModel> expenses) async {
    await _box.clear();
    await _box.putAll(
      {for (final e in expenses) e.id: jsonEncode(e.toCache())},
    );
  }

  @override
  Future<void> delete(String id) => _box.delete(id);

  ExpenseModel? _decode(Object? value) {
    if (value is! String) return null;
    try {
      return ExpenseModel.fromMap(jsonDecode(value) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }
}
