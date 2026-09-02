import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/domain/entities/account_type.dart';
import 'package:finora/features/wallet/presentation/viewmodels/wallet_controller.dart';
import 'package:finora/features/wallet/presentation/viewmodels/wallet_providers.dart';

part 'add_account_controller.g.dart';

@riverpod
class AddAccountController extends _$AddAccountController {
  @override
  FutureOr<void> build() {}

  String get _userId =>
      ref.read(authControllerProvider).user?.id ?? 'local-user';

  Future<bool> save({
    String? id,
    required String name,
    required AccountType type,
    required double openingBalance,
    required String color,
    required String icon,
    String? bankName,
    String? accountNumberLast4,
  }) async {
    state = const AsyncLoading();

    final isEditing = id != null && id.isNotEmpty;

    final account = Account(
      id: id ?? '',
      userId: _userId,
      name: name.trim(),
      type: type,
      currency: 'INR', // TODO: Make configurable later
      openingBalance: openingBalance,
      currentBalance: openingBalance, // For a new account, current == opening
      icon: icon,
      color: color,
      isDefault: false,
      bankName: bankName?.trim(),
      accountNumberLast4: accountNumberLast4?.trim(),
    );

    final result = isEditing
        ? await ref.read(updateAccountUseCaseProvider)(account)
        : await ref.read(addAccountUseCaseProvider)(account);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        ref.invalidate(walletControllerProvider);
        state = const AsyncData(null);
        return true;
      },
    );
  }
}
