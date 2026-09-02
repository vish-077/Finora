import 'package:equatable/equatable.dart';
import 'package:finora/shared/enums/transaction_type.dart';

/// A spending/income category (e.g. Food, Salary).
class Category extends Equatable {
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    this.type = TransactionType.expense,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;

  /// Material icon name (see [iconData] mapping in the UI layer).
  final String icon;

  /// Hex color string, e.g. `#3498DB`.
  final String color;
  final TransactionType type;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category copyWith({
    String? name,
    String? icon,
    String? color,
    TransactionType? type,
  }) =>
      Category(
        id: id,
        userId: userId,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        type: type ?? this.type,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [id, userId, name, icon, color, type];
}
