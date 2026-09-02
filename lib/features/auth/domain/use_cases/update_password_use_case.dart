import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call(String newPassword) =>
      _repository.updatePassword(newPassword);
}
