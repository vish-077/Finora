import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/features/wallet/domain/repositories/account_repository.dart';
import 'package:finora/features/wallet/domain/use_cases/account_use_cases.dart';

import 'package:finora/features/wallet/domain/entities/account.dart';

part 'wallet_providers.g.dart';

@riverpod
AccountRepository accountRepository(AccountRepositoryRef ref) =>
    sl<AccountRepository>();

@riverpod
GetAccountsUseCase getAccountsUseCase(GetAccountsUseCaseRef ref) =>
    sl<GetAccountsUseCase>();

@riverpod
GetAccountByIdUseCase getAccountByIdUseCase(GetAccountByIdUseCaseRef ref) =>
    sl<GetAccountByIdUseCase>();

@riverpod
AddAccountUseCase addAccountUseCase(AddAccountUseCaseRef ref) =>
    sl<AddAccountUseCase>();

@riverpod
UpdateAccountUseCase updateAccountUseCase(UpdateAccountUseCaseRef ref) =>
    sl<UpdateAccountUseCase>();

@riverpod
DeleteAccountUseCase deleteAccountUseCase(DeleteAccountUseCaseRef ref) =>
    sl<DeleteAccountUseCase>();

@riverpod
Stream<List<Account>> accountsStream(AccountsStreamRef ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
}
