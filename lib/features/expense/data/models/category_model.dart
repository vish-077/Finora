import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.icon,
    required super.color,
    super.type,
    super.createdAt,
    super.updatedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        icon: (map['icon'] as String?) ?? 'category',
        color: (map['color'] as String?) ?? '#3498DB',
        type: TransactionTypeWire.fromWire(map['type'] as String?),
        createdAt: _date(map['created_at']),
        updatedAt: _date(map['updated_at']),
      );

  factory CategoryModel.fromEntity(Category c) => CategoryModel(
        id: c.id,
        userId: c.userId,
        name: c.name,
        icon: c.icon,
        color: c.color,
        type: c.type,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  /// Payload for insert/update (id/user_id handled by caller/RLS).
  Map<String, dynamic> toInsert() => <String, dynamic>{
        'user_id': userId,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type.wire,
      };

  Map<String, dynamic> toCache() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type.wire,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
}
