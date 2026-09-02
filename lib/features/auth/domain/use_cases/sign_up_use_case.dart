import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthUser>> call({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _repository.signUp(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      );
}
