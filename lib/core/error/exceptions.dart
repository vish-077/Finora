class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'AppException[$code]: $message';
}

class LocalException extends AppException {
  const LocalException(super.message, {super.code, super.cause});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause, this.statusCode});

  final int? statusCode;
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

class SyncException extends AppException {
  const SyncException(super.message, {super.code, super.cause});
}

class AIException extends AppException {
  const AIException(super.message, {super.code, super.cause});
}

class OcrException extends AppException {
  const OcrException(super.message, {super.code, super.cause});
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause, this.field});

  final String? field;
}
