import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/receipt_repository.dart';

class SaveReceiptUseCase {
  const SaveReceiptUseCase(this._repository);

  final ReceiptRepository _repository;

  Future<void> call(Receipt receipt) async {
    return _repository.saveReceipt(receipt);
  }
}
