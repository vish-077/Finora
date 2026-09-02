import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/domain/repositories/account_repository.dart';

class GetAccountsUseCase {
  const GetAccountsUseCase(this._repository);
  final AccountRepository _repository;

  Future<Either<Failure, List<Account>>> call() => _repository.getAccounts();
}

class GetAccountByIdUseCase {
  const GetAccountByIdUseCase(this._repository);
  final AccountRepository _repository;

  Future<Either<Failure, Account>> call(String id) =>
      _repository.getAccountById(id);
}

class AddAccountUseCase {
  const AddAccountUseCase(this._repository);
  final AccountRepository _repository;

  Future<Either<Failure, Account>> call(Account account) =>
      _repository.addAccount(account);
}

class UpdateAccountUseCase {
  const UpdateAccountUseCase(this._repository);
  final AccountRepository _repository;

  Future<Either<Failure, Account>> call(Account account) =>
      _repository.updateAccount(account);
}

class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);
  final AccountRepository _repository;

  Future<Either<Failure, Unit>> call(String id) =>
      _repository.deleteAccount(id);
}
