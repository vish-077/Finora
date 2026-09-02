import 'package:equatable/equatable.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_item.dart';

class ReceiptData extends Equatable {
  const ReceiptData({
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.time,
    required this.category,
    required this.paymentMethod,
    required this.tax,
    required this.discount,
    required this.items,
    required this.confidenceScore,
  });

  final String merchantName;
  final double totalAmount;
  final DateTime date;
  final String time;
  final String category;
  final String paymentMethod;
  final double tax;
  final double discount;
  final List<ReceiptItem> items;
  final double confidenceScore;

  Map<String, dynamic> toMap() => {
        'merchantName': merchantName,
        'totalAmount': totalAmount,
        'date': date.toIso8601String(),
        'time': time,
        'category': category,
        'paymentMethod': paymentMethod,
        'tax': tax,
        'discount': discount,
        'items': items.map((x) => x.toMap()).toList(),
        'confidenceScore': confidenceScore,
      };

  factory ReceiptData.fromMap(Map<String, dynamic> map) {
    return ReceiptData(
      merchantName: map['merchantName'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      time: map['time'] as String? ?? '',
      category: map['category'] as String? ?? '',
      paymentMethod: map['paymentMethod'] as String? ?? '',
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      items: (map['items'] as List<dynamic>?)
              ?.map((x) => ReceiptItem.fromMap(Map<String, dynamic>.from(x as Map)))
              .toList() ??
          [],
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 1.0,
    );
  }

  ReceiptData copyWith({
    String? merchantName,
    double? totalAmount,
    DateTime? date,
    String? time,
    String? category,
    String? paymentMethod,
    double? tax,
    double? discount,
    List<ReceiptItem>? items,
    double? confidenceScore,
  }) {
    return ReceiptData(
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      time: time ?? this.time,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      items: items ?? this.items,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }

  @override
  List<Object?> get props => [
        merchantName,
        totalAmount,
        date,
        time,
        category,
        paymentMethod,
        tax,
        discount,
        items,
        confidenceScore,
      ];
}
