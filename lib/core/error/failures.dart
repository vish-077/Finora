import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

// ── Local Storage Failures ─────────────────────────────────────────────────
final class LocalFailure extends Failure {
  const LocalFailure(super.message, {super.code});
}

final class StorageReadFailure extends LocalFailure {
  const StorageReadFailure(super.message) : super(code: 'STORAGE_READ');
}

final class StorageWriteFailure extends LocalFailure {
  const StorageWriteFailure(super.message) : super(code: 'STORAGE_WRITE');
}

// ── Network Failures ──────────────────────────────────────────────────────
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

final class NoInternetFailure extends NetworkFailure {
  const NoInternetFailure() : super('No internet connection', code: 'NO_INTERNET');
}

final class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure() : super('Request timed out', code: 'TIMEOUT');
}

final class ServerFailure extends NetworkFailure {
  const ServerFailure(super.message, {super.code, this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [...super.props, statusCode];
}

// ── Auth Failures ─────────────────────────────────────────────────────────
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

final class InvalidCredentialsFailure extends AuthFailure {
  /// Firebase reports a wrong password and an unknown address the same way
  /// (it avoids revealing which addresses exist), so the message doesn't claim
  /// to know which one it was.
  const InvalidCredentialsFailure()
      : super(
          'Email or password is incorrect.',
          code: 'INVALID_CREDENTIALS',
        );
}

final class InvalidEmailDomainFailure extends AuthFailure {
  const InvalidEmailDomainFailure()
      : super('Only @gmail.com accounts are supported', code: 'INVALID_EMAIL_DOMAIN');
}

final class PinLockedFailure extends AuthFailure {
  const PinLockedFailure(int minutesRemaining)
      : super(
          'Account locked. Try again in $minutesRemaining minutes.',
          code: 'PIN_LOCKED',
        );
}

final class BiometricUnavailableFailure extends AuthFailure {
  const BiometricUnavailableFailure()
      : super('Biometric authentication not available', code: 'BIOMETRIC_UNAVAILABLE');
}

final class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure()
      : super('Session expired. Please log in again.', code: 'SESSION_EXPIRED');
}

final class UnauthorizedFailure extends AuthFailure {
  const UnauthorizedFailure()
      : super('Unauthorized access', code: 'UNAUTHORIZED');
}

// ── Validation Failures ───────────────────────────────────────────────────
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, this.field});

  final String? field;

  @override
  List<Object?> get props => [...super.props, field];
}

// ── Sync Failures ─────────────────────────────────────────────────────────
final class SyncFailure extends Failure {
  const SyncFailure(super.message, {super.code});
}

final class ConflictFailure extends SyncFailure {
  const ConflictFailure(super.message) : super(code: 'SYNC_CONFLICT');
}

// ── AI Failures ───────────────────────────────────────────────────────────
final class AIFailure extends Failure {
  const AIFailure(super.message, {super.code});
}

final class AIKeyNotSetFailure extends AIFailure {
  const AIKeyNotSetFailure()
      : super('Gemini API key not configured', code: 'AI_KEY_NOT_SET');
}

final class AIQuotaExceededFailure extends AIFailure {
  const AIQuotaExceededFailure()
      : super('AI API quota exceeded', code: 'AI_QUOTA_EXCEEDED');
}

// ── OCR Failures ─────────────────────────────────────────────────────────
final class OcrFailure extends Failure {
  const OcrFailure(super.message, {super.code});
}

final class OcrLowConfidenceFailure extends OcrFailure {
  OcrLowConfidenceFailure(double confidence)
      : super(
          'OCR confidence too low (${(confidence * 100).toStringAsFixed(0)}%)',
          code: 'OCR_LOW_CONFIDENCE',
        ) {
    // ignore: use_super_parameters — can't use super when message is computed
  }
}

// ── Permission Failures ───────────────────────────────────────────────────
final class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}

final class CameraPermissionFailure extends PermissionFailure {
  const CameraPermissionFailure()
      : super('Camera permission denied', code: 'CAMERA_PERMISSION');
}

// ── Unknown ───────────────────────────────────────────────────────────────
final class UnknownFailure extends Failure {
  const UnknownFailure([String message = 'An unexpected error occurred'])
      : super(message, code: 'UNKNOWN');
}
