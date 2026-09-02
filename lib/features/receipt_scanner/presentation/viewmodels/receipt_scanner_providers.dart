import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/ocr_repository.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/receipt_repository.dart';
import 'package:finora/features/receipt_scanner/domain/services/receipt_parser.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/scan_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/parse_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/save_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/domain/use_cases/categorize_receipt_use_case.dart';
import 'package:finora/features/receipt_scanner/data/repositories/ocr_repository_impl.dart';
import 'package:finora/features/receipt_scanner/data/repositories/receipt_repository_impl.dart';
import 'package:finora/features/receipt_scanner/data/services/receipt_parser_impl.dart';

part 'receipt_scanner_providers.g.dart';

@riverpod
OcrRepository ocrRepository(OcrRepositoryRef ref) {
  return OcrRepositoryImpl();
}

@riverpod
ReceiptRepository receiptRepository(ReceiptRepositoryRef ref) {
  return ReceiptRepositoryImpl();
}

@riverpod
ReceiptParser receiptParser(ReceiptParserRef ref) {
  return const ReceiptParserImpl();
}

@riverpod
ScanReceiptUseCase scanReceiptUseCase(ScanReceiptUseCaseRef ref) {
  return ScanReceiptUseCase(ref.watch(ocrRepositoryProvider));
}

@riverpod
ParseReceiptUseCase parseReceiptUseCase(ParseReceiptUseCaseRef ref) {
  return ParseReceiptUseCase(ref.watch(receiptParserProvider));
}

@riverpod
SaveReceiptUseCase saveReceiptUseCase(SaveReceiptUseCaseRef ref) {
  return SaveReceiptUseCase(ref.watch(receiptRepositoryProvider));
}

@riverpod
CategorizeReceiptUseCase categorizeReceiptUseCase(CategorizeReceiptUseCaseRef ref) {
  return const CategorizeReceiptUseCase();
}
