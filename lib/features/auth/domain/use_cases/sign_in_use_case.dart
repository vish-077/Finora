import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/entities/auth_session.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthSession>> call({
    required String email,
    required String password,
  }) =>
      _repository.signIn(email: email.trim(), password: password);
}
