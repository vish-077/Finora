import 'package:finora/features/receipt_scanner/domain/repositories/ocr_repository.dart';

class ScanReceiptUseCase {
  const ScanReceiptUseCase(this._ocrRepository);

  final OcrRepository _ocrRepository;

  Future<String> call(String imagePath) async {
    return _ocrRepository.recognizeText(imagePath);
  }
}
