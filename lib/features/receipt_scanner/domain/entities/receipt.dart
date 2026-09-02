import 'package:equatable/equatable.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_data.dart';

class Receipt extends Equatable {
  const Receipt({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.ocrText,
    required this.parsedData,
    this.transactionId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String imagePath;
  final String ocrText;
  final ReceiptData parsedData;
  final String? transactionId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'imagePath': imagePath,
        'ocrText': ocrText,
        'parsedData': parsedData.toMap(),
        'transactionId': transactionId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      imagePath: map['imagePath'] as String? ?? '',
      ocrText: map['ocrText'] as String? ?? '',
      parsedData: ReceiptData.fromMap(Map<String, dynamic>.from(map['parsedData'] as Map? ?? {})),
      transactionId: map['transactionId'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
    );
  }

  Receipt copyWith({
    String? id,
    String? userId,
    String? imagePath,
    String? ocrText,
    ReceiptData? parsedData,
    String? transactionId,
    DateTime? createdAt,
  }) {
    return Receipt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imagePath: imagePath ?? this.imagePath,
      ocrText: ocrText ?? this.ocrText,
      parsedData: parsedData ?? this.parsedData,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        imagePath,
        ocrText,
        parsedData,
        transactionId,
        createdAt,
      ];
}
