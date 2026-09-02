import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.signOut();
}
