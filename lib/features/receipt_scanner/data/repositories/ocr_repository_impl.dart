import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:finora/features/receipt_scanner/domain/repositories/ocr_repository.dart';

class OcrRepositoryImpl implements OcrRepository {
  OcrRepositoryImpl();

  @override
  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer
          .processImage(inputImage)
          .timeout(const Duration(seconds: 15));
      return recognizedText.text;
    } finally {
      // Close the recognizer after a short delay to prevent platform channel collisions
      // (Future already completed errors) when closing is done synchronously.
      Future.delayed(const Duration(milliseconds: 200), () {
        textRecognizer.close().catchError((e) {
          debugPrint('Error closing text recognizer: $e');
        });
      });
    }
  }
}
