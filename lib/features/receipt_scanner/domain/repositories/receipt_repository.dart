import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';

abstract interface class ReceiptRepository {
  Future<List<Receipt>> getReceipts();
  Future<Receipt?> getReceiptById(String id);
  Future<void> saveReceipt(Receipt receipt);
  Future<void> deleteReceipt(String id);
  Future<bool> checkDuplicate(double amount, DateTime date, String merchantName);
  Future<List<Receipt>> searchReceipts(String query);
}
