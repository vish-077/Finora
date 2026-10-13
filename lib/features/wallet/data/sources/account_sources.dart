import 'dart:convert';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/core/sync/stable_id.dart';
import 'package:finora/features/wallet/data/models/account_model.dart';
import 'package:finora/features/wallet/domain/entities/account_type.dart';

// ── Default Accounts (used offline / before first cloud sync) ──────────────
List<AccountModel> defaultAccounts(String userId) => [
      AccountModel(
        id: stableId('account:$userId:cash'),
        userId: userId,
        name: 'Cash Wallet',
        type: AccountType.cash,
        currency: 'INR',
        openingBalance: 0,
        currentBalance: 0,
        icon: 'account_balance_wallet',
        color: '#2ECC71',
        isDefault: true,
      ),
    ];

// ── Local ─────────────────────────────────────────────────────────────────────
abstract interface class AccountLocalSource {
  List<AccountModel> readAll();
  AccountModel? readById(String id);
  Future<void> replaceAll(List<AccountModel> accounts);
  Future<void> upsert(AccountModel account);
  Future<void> delete(String id);
}

class AccountLocalSourceImpl implements AccountLocalSource {
  AccountLocalSourceImpl(this._box);

  final SqlBox _box;

  @override
  List<AccountModel> readAll() {
    final result = <AccountModel>[];
    for (final value in _box.values) {
      if (value is! String) continue;
      try {
        result.add(
          AccountModel.fromMap(jsonDecode(value) as Map<String, dynamic>),
        );
      } on FormatException {
        continue;
      }
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  AccountModel? readById(String id) {
    final value = _box.get(id);
    if (value is String) {
      try {
        return AccountModel.fromMap(jsonDecode(value) as Map<String, dynamic>);
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> replaceAll(List<AccountModel> accounts) async {
    await _box.clear();
    await _box.putAll(
      {for (final a in accounts) a.id: jsonEncode(a.toCache())},
    );
  }

  @override
  Future<void> upsert(AccountModel account) =>
      _box.put(account.id, jsonEncode(account.toCache()));

  @override
  Future<void> delete(String id) => _box.delete(id);
}
