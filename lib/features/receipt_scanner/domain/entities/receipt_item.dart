import 'package:equatable/equatable.dart';

class ReceiptItem extends Equatable {
  const ReceiptItem({
    required this.name,
    required this.price,
  });

  final String name;
  final double price;

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
      };

  factory ReceiptItem.fromMap(Map<String, dynamic> map) => ReceiptItem(
        name: map['name'] as String? ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  List<Object?> get props => [name, price];
}
