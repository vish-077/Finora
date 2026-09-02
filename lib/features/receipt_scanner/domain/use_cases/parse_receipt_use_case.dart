import 'package:finora/features/receipt_scanner/domain/entities/receipt_data.dart';
import 'package:finora/features/receipt_scanner/domain/services/receipt_parser.dart';

class ParseReceiptUseCase {
  const ParseReceiptUseCase(this._parser);

  final ReceiptParser _parser;

  ReceiptData call(String ocrText) {
    return _parser.parse(ocrText);
  }
}
