import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';

abstract class AccountRepository {
  Future<Either<Failure, List<Account>>> getAccounts();
  Future<Either<Failure, Account>> getAccountById(String id);
  Future<Either<Failure, Account>> addAccount(Account account);
  Future<Either<Failure, Account>> updateAccount(Account account);
  Future<Either<Failure, Unit>> deleteAccount(String id);
  Stream<List<Account>> watchAccounts();
}
