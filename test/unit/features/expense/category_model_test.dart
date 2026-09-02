import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/expense/data/models/category_model.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/shared/enums/transaction_type.dart';

void main() {
  group('CategoryModel', () {
    const testCategory = Category(
      id: 'cat-1',
      userId: 'user-1',
      name: 'Food',
      icon: 'restaurant',
      color: '#FF5722',
      type: TransactionType.expense,
    );

    test('fromEntity preserves all fields', () {
      final model = CategoryModel.fromEntity(testCategory);
      expect(model.id, testCategory.id);
      expect(model.userId, testCategory.userId);
      expect(model.name, testCategory.name);
      expect(model.icon, testCategory.icon);
      expect(model.color, testCategory.color);
      expect(model.type, testCategory.type);
    });

    test('toCache and fromMap round-trip', () {
      final model = CategoryModel.fromEntity(testCategory);
      final cache = model.toCache();
      final restored = CategoryModel.fromMap(cache);
      expect(restored.id, model.id);
      expect(restored.userId, model.userId);
      expect(restored.name, model.name);
      expect(restored.icon, model.icon);
      expect(restored.color, model.color);
      expect(restored.type, model.type);
    });

    test('fromMap handles missing icon and color', () {
      final map = <String, dynamic>{
        'id': 'id-1',
        'user_id': 'user-1',
        'name': 'Test',
      };
      final model = CategoryModel.fromMap(map);
      expect(model.icon, 'category');
      expect(model.color, '#3498DB');
      expect(model.type, TransactionType.expense);
    });

    test('toInsert excludes id and timestamps', () {
      final model = CategoryModel.fromEntity(testCategory);
      final insert = model.toInsert();
      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
      expect(insert['user_id'], testCategory.userId);
      expect(insert['name'], testCategory.name);
      expect(insert['type'], 'expense');
    });
  });

  group('Category entity', () {
    test('copyWith preserves unchanged fields', () {
      const original = Category(
        id: 'c1',
        userId: 'u1',
        name: 'Food',
        icon: 'restaurant',
        color: '#FF5722',
      );
      final copy = original.copyWith(name: 'Dining');
      expect(copy.name, 'Dining');
      expect(copy.id, original.id);
      expect(copy.icon, original.icon);
      expect(copy.color, original.color);
    });

    test('equatable works correctly', () {
      const a = Category(
        id: 'c1', userId: 'u1', name: 'Food', icon: 'restaurant', color: '#FF5722',
      );
      const b = Category(
        id: 'c1', userId: 'u1', name: 'Food', icon: 'restaurant', color: '#FF5722',
      );
      expect(a, equals(b));
    });
  });
}
