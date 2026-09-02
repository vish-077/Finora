import 'package:finora/features/receipt_scanner/domain/entities/receipt_data.dart';

abstract interface class ReceiptParser {
  ReceiptData parse(String ocrText);
}
