import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/presentation/viewmodels/wallet_providers.dart';

part 'wallet_controller.g.dart';

@riverpod
class WalletController extends _$WalletController {
  @override
  FutureOr<List<Account>> build() {
    final accountsAsync = ref.watch(accountsStreamProvider);
    if (accountsAsync.hasValue) {
      return accountsAsync.value!;
    }
    return _fetchAccounts();
  }

  Future<List<Account>> _fetchAccounts() async {
    final useCase = ref.watch(getAccountsUseCaseProvider);
    final result = await useCase();
    return result.fold(
      (failure) => throw failure,
      (accounts) => accounts,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchAccounts);
  }

  Future<Failure?> deleteAccount(String id) async {
    final useCase = ref.read(deleteAccountUseCaseProvider);
    final result = await useCase(id);
    return result.fold(
      (failure) => failure,
      (_) {
        refresh();
        return null;
      },
    );
  }
}
