abstract interface class OcrRepository {
  Future<String> recognizeText(String imagePath);
}
