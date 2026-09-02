import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_data.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt_item.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/ocr_repository.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/receipt_repository.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/scan_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/parse_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/save_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/categorize_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/data/services/receipt_parser_impl.dart';

class _MockOcrRepository implements OcrRepository {
  String recognizedText = '';
  @override
  Future<String> recognizeText(String imagePath) async => recognizedText;
}

class _MockReceiptRepository implements ReceiptRepository {
  List<Receipt> receipts = [];
  bool duplicateValue = false;
  Receipt? lastSaved;

  @override
  Future<List<Receipt>> getReceipts() async => receipts;

  @override
  Future<Receipt?> getReceiptById(String id) async =>
      receipts.firstWhere((r) => r.id == id);

  @override
  Future<void> saveReceipt(Receipt receipt) async {
    lastSaved = receipt;
    receipts.add(receipt);
  }

  @override
  Future<void> deleteReceipt(String id) async {
    receipts.removeWhere((r) => r.id == id);
  }

  @override
  Future<bool> checkDuplicate(double amount, DateTime date, String merchantName) async =>
      duplicateValue;

  @override
  Future<List<Receipt>> searchReceipts(String query) async {
    if (query.isEmpty) return receipts;
    return receipts.where((r) => r.parsedData.merchantName.contains(query)).toList();
  }
}

void main() {
  group('ReceiptParserImpl Tests', () {
    const parser = ReceiptParserImpl();

    test('Parses typical receipt format with items and grand total', () {
      const ocrText = '''
      STARBUCKS COFFEE
      Store #12345
      Date: 2026-07-15
      Time: 09:30 AM
      
      Caffe Latte    4.50
      Croissant      3.50
      
      Subtotal       8.00
      Tax            0.64
      Total          8.64
      
      Payment Method: Credit Card
      ''';

      final data = parser.parse(ocrText);

      expect(data.merchantName, 'STARBUCKS COFFEE');
      expect(data.totalAmount, 8.64);
      expect(data.tax, 0.64);
      expect(data.paymentMethod, 'creditCard');
      expect(data.items.length, 2);
      expect(data.items[0].name.trim(), 'Caffe Latte');
      expect(data.items[0].price, 4.50);
      expect(data.items[1].name.trim(), 'Croissant');
      expect(data.items[1].price, 3.50);
    });

    test('Parses date and time correctly', () {
      const ocrText = 'Date: 2026-05-20\nTime: 14:45\nTotal: 15.00';
      final data = parser.parse(ocrText);
      expect(data.date.year, 2026);
      expect(data.date.month, 5);
      expect(data.date.day, 20);
      expect(data.time, '14:45');
    });
  });

  group('CategorizeReceiptUseCase Tests', () {
    const useCase = CategorizeReceiptUseCase();

    test('Classifies food and drinks correctly', () {
      expect(useCase('Starbucks'), 'Food');
      expect(useCase('McDonalds'), 'Food');
      expect(useCase('Deli & Restaurant'), 'Food');
    });

    test('Classifies shopping and groceries correctly', () {
      expect(useCase('Amazon Store'), 'Shopping');
      expect(useCase('Reliance Fresh'), 'Food');
      expect(useCase('Supermarket Mart'), 'Food');
    });

    test('Classifies travel and fuel correctly', () {
      expect(useCase('Uber Ride'), 'Travel');
      expect(useCase('Shell Petrol Station'), 'Fuel');
    });
  });

  group('Receipt Use Cases Tests', () {
    late _MockOcrRepository mockOcrRepo;
    late _MockReceiptRepository mockReceiptRepo;

    setUp(() {
      mockOcrRepo = _MockOcrRepository();
      mockReceiptRepo = _MockReceiptRepository();
    });

    test('ScanReceiptUseCase gets text from repository', () async {
      mockOcrRepo.recognizedText = 'Scanned Text';
      final useCase = ScanReceiptUseCase(mockOcrRepo);
      final result = await useCase('dummy_path');
      expect(result, 'Scanned Text');
    });

    test('SaveReceiptUseCase saves to repository', () async {
      final useCase = SaveReceiptUseCase(mockReceiptRepo);
      final receipt = Receipt(
        id: 'r1',
        userId: 'u1',
        imagePath: 'path',
        ocrText: 'ocr',
        parsedData: ReceiptData(
          merchantName: 'Store',
          totalAmount: 10.0,
          date: DateTime.now(),
          time: '12:00',
          category: 'Food',
          paymentMethod: 'cash',
          tax: 0.0,
          discount: 0.0,
          items: const [],
          confidenceScore: 0.9,
        ),
        createdAt: DateTime.now(),
      );

      await useCase(receipt);
      expect(mockReceiptRepo.lastSaved, receipt);
    });
  });
}
