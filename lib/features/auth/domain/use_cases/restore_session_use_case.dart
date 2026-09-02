import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/entities/auth_session.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

/// Auto-login: restore a persisted session on cold start.
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthSession?>> call() => _repository.restoreSession();
}
