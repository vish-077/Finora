import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/security/biometric_service.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

/// Unlocks the app with biometrics, then restores the stored session.
class AuthenticateBiometricUseCase {
  const AuthenticateBiometricUseCase(this._biometrics, this._repository);

  final BiometricService _biometrics;
  final AuthRepository _repository;

  Future<Either<Failure, bool>> call({required String reason}) async {
    if (!await _repository.isBiometricEnabled()) {
      return left(const BiometricUnavailableFailure());
    }
    if (!await _biometrics.isAvailable()) {
      return left(const BiometricUnavailableFailure());
    }
    return _biometrics.authenticate(reason: reason);
  }
}
