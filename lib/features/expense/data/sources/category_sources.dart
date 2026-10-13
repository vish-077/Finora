import 'dart:convert';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/core/sync/stable_id.dart';
import 'package:finora/features/expense/data/models/category_model.dart';
import 'package:finora/shared/enums/transaction_type.dart';

// ── Default categories (used offline / before first cloud sync) ──────────────
const _defaultSeed = <(String, String, String, TransactionType)>[
  // Expenses
  ('Food', 'restaurant', '#FF5722', TransactionType.expense),
  ('Fuel', 'local_gas_station', '#FF9800', TransactionType.expense),
  ('Bills', 'receipt_long', '#1ABC9C', TransactionType.expense),
  ('Shopping', 'shopping_bag', '#E74C3C', TransactionType.expense),
  ('Medical', 'local_hospital', '#27AE60', TransactionType.expense),
  ('Recharge', 'phone_android', '#4CAF50', TransactionType.expense),
  ('Travel', 'flight', '#00BCD4', TransactionType.expense),
  ('Education', 'school', '#E67E22', TransactionType.expense),
  ('Entertainment', 'movie', '#9B59B6', TransactionType.expense),
  ('Others', 'more_horiz', '#607D8B', TransactionType.expense),
  // Incomes
  ('Salary', 'payments', '#2ECC71', TransactionType.income),
  ('Freelance', 'work', '#3498DB', TransactionType.income),
  ('Business', 'store', '#9B59B6', TransactionType.income),
  ('Investment', 'trending_up', '#1ABC9C', TransactionType.income),
  ('Bonus', 'card_giftcard', '#E67E22', TransactionType.income),
  ('Refund', 'settings_backup_restore', '#E74C3C', TransactionType.income),
  ('Interest', 'account_balance', '#2980B9', TransactionType.income),
  ('Gift', 'volunteer_activism', '#F1C40F', TransactionType.income),
  ('Cashback', 'monetization_on', '#27AE60', TransactionType.income),
  ('Rental Income', 'home', '#34495E', TransactionType.income),
  ('Other Income', 'more_horiz', '#95A5A6', TransactionType.income),
];

List<CategoryModel> defaultCategories(String userId) => [
      for (final (name, icon, color, type) in _defaultSeed)
        CategoryModel(
          id: stableId('category:$userId:${name.toLowerCase()}'),
          userId: userId,
          name: name,
          icon: icon,
          color: color,
          type: type,
        ),
    ];

// ── Local ─────────────────────────────────────────────────────────────────────
abstract interface class CategoryLocalSource {
  List<CategoryModel> readAll();
  Future<void> replaceAll(List<CategoryModel> categories);
  Future<void> upsert(CategoryModel category);
  Future<void> delete(String id);
}

class CategoryLocalSourceImpl implements CategoryLocalSource {
  CategoryLocalSourceImpl(this._box);

  final SqlBox _box;

  @override
  List<CategoryModel> readAll() {
    final result = <CategoryModel>[];
    for (final value in _box.values) {
      if (value is! String) continue;
      try {
        result.add(
          CategoryModel.fromMap(jsonDecode(value) as Map<String, dynamic>),
        );
      } on FormatException {
        continue;
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Future<void> replaceAll(List<CategoryModel> categories) async {
    await _box.clear();
    await _box.putAll(
      {for (final c in categories) c.id: jsonEncode(c.toCache())},
    );
  }

  @override
  Future<void> upsert(CategoryModel category) =>
      _box.put(category.id, jsonEncode(category.toCache()));

  @override
  Future<void> delete(String id) => _box.delete(id);
}
