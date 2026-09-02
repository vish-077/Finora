import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/receipt_scanner/domain/entities/receipt.dart';
import 'package:finora/features/receipt_scanner/presentation/viewmodels/receipt_scanner_providers.dart';

part 'receipt_detail_controller.g.dart';

@riverpod
class ReceiptDetailController extends _$ReceiptDetailController {
  @override
  FutureOr<Receipt?> build(String id) async {
    return ref.read(receiptRepositoryProvider).getReceiptById(id);
  }

  Future<void> updateReceipt(Receipt receipt) async {
    state = const AsyncLoading();
    try {
      await ref.read(receiptRepositoryProvider).saveReceipt(receipt);
      state = AsyncData(receipt);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}
