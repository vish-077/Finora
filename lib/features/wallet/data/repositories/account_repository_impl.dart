import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_tables.dart';
import 'package:finora/core/sync/sync_writer.dart';
import 'package:finora/features/wallet/data/models/account_model.dart';
import 'package:finora/features/wallet/data/sources/account_sources.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required AccountLocalSource local,
    required SyncWriter sync,
    required SyncLocalStore store,
    required String Function() currentUserId,
    Uuid? uuid,
  })  : _local = local,
        _sync = sync,
        _store = store,
        _currentUserId = currentUserId,
        _uuid = uuid ?? const Uuid();

  /// Sentinel used by DI when there is no Firebase session.
  static const String _anonymousUser = 'local-user';

  final AccountLocalSource _local;
  final SyncWriter _sync;
  final SyncLocalStore _store;
  final String Function() _currentUserId;
  final Uuid _uuid;

  @override
  Future<Either<Failure, List<Account>>> getAccounts() async {
    try {
      await _sync.prepareRead();
      var list = _local.readAll();

      if (list.isEmpty) list = await _seedDefaults();

      return right(list);
    } catch (e) {
      return left(StorageReadFailure('Failed to read accounts: $e'));
    }
  }

  /// Seeds the default wallet for an empty account. Ids are deterministic, so
  /// two devices seeding while offline converge on one row after sync.
  Future<List<AccountModel>> _seedDefaults() async {
    final userId = _currentUserId();
    final defaults = defaultAccounts(userId);

    for (final account in defaults) {
      if (userId == _anonymousUser) {
        await _local.upsert(account);
      } else {
        await _sync.save(SyncTables.accounts, account.toCache());
      }
    }
    return defaults;
  }

  @override
  Future<Either<Failure, Account>> getAccountById(String id) async {
    final cached = _local.readById(id);
    if (cached != null) return right(cached);

    await _sync.prepareRead();
    final afterSync = _local.readById(id);
    if (afterSync != null) return right(afterSync);

    return left(const LocalFailure('Account not found'));
  }

  @override
  Future<Either<Failure, Account>> addAccount(Account account) {
    final withId =
        account.id.isEmpty ? account.copyWith(id: _uuid.v4()) : account;
    return _write(withId, 'save');
  }

  @override
  Future<Either<Failure, Account>> updateAccount(Account account) =>
      _write(account, 'update');

  Future<Either<Failure, Account>> _write(Account account, String verb) async {
    try {
      final model = AccountModel.fromEntity(account);
      final stored = await _sync.save(SyncTables.accounts, model.toCache());
      return right(AccountModel.fromMap(stored));
    } catch (e) {
      return left(StorageWriteFailure('Failed to $verb account: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteAccount(String id) async {
    try {
      await _sync.remove(SyncTables.accounts, id);
      return right(unit);
    } catch (e) {
      return left(StorageWriteFailure('Failed to delete account: $e'));
    }
  }

  @override
  Stream<List<Account>> watchAccounts() async* {
    yield _local.readAll();
    yield* _store.box(SyncTables.accounts).watch().map((_) => _local.readAll());
  }
}
