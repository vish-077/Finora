import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';
import 'package:finora/features/receipt_scanner/presentation/viewmodels/receipt_scanner_providers.dart';

part 'receipt_scanner_controller.g.dart';

@riverpod
class ReceiptScannerController extends _$ReceiptScannerController {
  @override
  FutureOr<List<Receipt>> build() async {
    return ref.read(receiptRepositoryProvider).getReceipts();
  }

  Future<void> saveReceipt(Receipt receipt) async {
    state = const AsyncLoading();
    try {
      await ref.read(saveReceiptUseCaseProvider)(receipt);
      final list = await ref.read(receiptRepositoryProvider).getReceipts();
      state = AsyncData(list);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<void> deleteReceipt(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(receiptRepositoryProvider).deleteReceipt(id);
      final list = await ref.read(receiptRepositoryProvider).getReceipts();
      state = AsyncData(list);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  Future<bool> checkDuplicate(double amount, DateTime date, String merchantName) async {
    return ref.read(receiptRepositoryProvider).checkDuplicate(amount, date, merchantName);
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    try {
      final list = await ref.read(receiptRepositoryProvider).searchReceipts(query);
      state = AsyncData(list);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}
