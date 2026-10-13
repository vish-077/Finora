import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/receipt_repository.dart';
import 'package:finora/core/constants/storage_constants.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  ReceiptRepositoryImpl();

  SqlBox get _box => AppDatabase.box(StorageBoxes.receipts);

  @override
  Future<List<Receipt>> getReceipts() async {
    final values = _box.values;
    return values
        .map((x) => Receipt.fromMap(Map<String, dynamic>.from(x as Map)))
        .toList();
  }

  @override
  Future<Receipt?> getReceiptById(String id) async {
    final data = _box.get(id);
    if (data == null) return null;
    return Receipt.fromMap(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> saveReceipt(Receipt receipt) async {
    await _box.put(receipt.id, receipt.toMap());
  }

  @override
  Future<void> deleteReceipt(String id) async {
    await _box.delete(id);
  }

  @override
  Future<bool> checkDuplicate(double amount, DateTime date, String merchantName) async {
    final receipts = await getReceipts();
    for (final r in receipts) {
      final sameAmount = (r.parsedData.totalAmount - amount).abs() < 0.01;
      final sameMerchant = r.parsedData.merchantName.toLowerCase().trim() == merchantName.toLowerCase().trim();
      final sameDate = r.parsedData.date.year == date.year &&
          r.parsedData.date.month == date.month &&
          r.parsedData.date.day == date.day;
      
      if (sameAmount && sameMerchant && sameDate) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<List<Receipt>> searchReceipts(String query) async {
    final receipts = await getReceipts();
    if (query.isEmpty) return receipts;
    final q = query.toLowerCase();

    return receipts.where((r) {
      final matchMerchant = r.parsedData.merchantName.toLowerCase().contains(q);
      final matchCategory = r.parsedData.category.toLowerCase().contains(q);
      final matchItems = r.parsedData.items.any((item) => item.name.toLowerCase().contains(q));
      return matchMerchant || matchCategory || matchItems;
    }).toList();
  }
}
