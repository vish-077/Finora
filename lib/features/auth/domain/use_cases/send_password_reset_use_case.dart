import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class SendPasswordResetUseCase {
  const SendPasswordResetUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call(String email) =>
      _repository.sendPasswordReset(email.trim());
}
