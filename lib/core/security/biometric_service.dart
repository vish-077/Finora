import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/logging/log_service.dart';

/// Wraps [LocalAuthentication] (Android BiometricPrompt / iOS FaceID/TouchID).
abstract interface class BiometricService {
  /// True when the device has hardware + enrolled biometrics available.
  Future<bool> isAvailable();

  /// Prompts the OS biometric dialog.
  /// Returns Right(true) on success, Right(false) on user cancel,
  /// or Left(Failure) on hardware / lockout errors.
  Future<Either<Failure, bool>> authenticate({required String reason});
}

class BiometricServiceImpl implements BiometricService {
  BiometricServiceImpl([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException catch (e) {
      LogService.w('Biometric availability check failed: ${e.code}');
      return false;
    }
  }

  @override
  Future<Either<Failure, bool>> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return right(ok);
    } on PlatformException catch (e) {
      return left(_mapError(e));
    }
  }

  Failure _mapError(PlatformException e) {
    LogService.w('Biometric auth error: ${e.code}');
    return switch (e.code) {
      auth_error.notAvailable ||
      auth_error.notEnrolled ||
      auth_error.passcodeNotSet =>
        const BiometricUnavailableFailure(),
      auth_error.lockedOut || auth_error.permanentlyLockedOut =>
        const AuthFailure('Too many attempts. Try again later.',
            code: 'BIOMETRIC_LOCKED'),
      _ => const AuthFailure('Biometric authentication failed',
          code: 'BIOMETRIC_ERROR'),
    };
  }
}
