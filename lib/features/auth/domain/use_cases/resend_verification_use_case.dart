import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class ResendVerificationUseCase {
  const ResendVerificationUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call(String email) =>
      _repository.resendVerificationEmail(email.trim());
}
