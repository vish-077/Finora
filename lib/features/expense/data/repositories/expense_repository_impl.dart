import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_tables.dart';
import 'package:finora/core/sync/sync_writer.dart';
import 'package:finora/features/expense/data/models/expense_model.dart';
import 'package:finora/features/expense/data/sources/expense_local_source.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';

/// Local-first. Reads come from the Hive mirror, writes go through
/// [SyncWriter]; the sync engine reconciles both directions with the server so
/// every device on the account converges on the same rows.
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({
    required ExpenseLocalSource local,
    required SyncWriter sync,
    required SyncLocalStore store,
    Uuid? uuid,
  })  : _local = local,
        _sync = sync,
        _store = store,
        _uuid = uuid ?? const Uuid();

  final ExpenseLocalSource _local;
  final SyncWriter _sync;
  final SyncLocalStore _store;
  final Uuid _uuid;

  @override
  Future<Either<Failure, List<Expense>>> getExpenses({
    ExpenseFilter? filter,
  }) async {
    try {
      // Blocks only on a device that has never pulled this account.
      await _sync.prepareRead();
      return right(applyFilter(_local.readAll(), filter));
    } catch (e) {
      return left(StorageReadFailure('Failed to read expenses: $e'));
    }
  }

  @override
  Future<Either<Failure, Expense>> getExpenseById(String id) async {
    final cached = _local.readById(id);
    if (cached != null) return right(cached);

    await _sync.prepareRead();
    final afterSync = _local.readById(id);
    if (afterSync != null) return right(afterSync);

    return left(const LocalFailure('Expense not found'));
  }

  @override
  Future<Either<Failure, List<Expense>>> getRecentTransactions({
    int limit = 5,
  }) async {
    final result = await getExpenses();
    return result.map((list) => list.take(limit).toList());
  }

  @override
  Future<Either<Failure, Expense>> addExpense(Expense expense) async {
    // The id is minted here, not by Postgres, so the row has one stable
    // identity on every device and re-pushing it is an idempotent upsert.
    final withId =
        expense.id.isEmpty ? expense.copyWith(id: _uuid.v4()) : expense;
    return _write(withId, 'save');
  }

  @override
  Future<Either<Failure, Expense>> updateExpense(Expense expense) =>
      _write(expense, 'update');

  Future<Either<Failure, Expense>> _write(Expense expense, String verb) async {
    try {
      final model = ExpenseModel.fromEntity(expense);
      final stored = await _sync.save(SyncTables.expenses, model.toCache());
      return right(ExpenseModel.fromMap(stored));
    } catch (e) {
      return left(StorageWriteFailure('Failed to $verb expense: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteExpense(String id) async {
    try {
      await _sync.remove(SyncTables.expenses, id);
      return right(unit);
    } catch (e) {
      return left(StorageWriteFailure('Failed to delete expense: $e'));
    }
  }

  @override
  Stream<List<Expense>> watchExpenses() async* {
    // The box is the single source of truth: local edits and rows merged in
    // from another device both land here, so one stream covers both.
    yield _local.readAll();
    yield* _store
        .box(SyncTables.expenses)
        .watch()
        .map((_) => _local.readAll());
  }

  // ── Filtering (in-memory over cached/remote list) ──────────────────────────
  @override
  List<Expense> applyFilter(List<Expense> list, ExpenseFilter? filter) {
    if (filter == null || !filter.isActive) return list;

    final range = filter.resolveRange(DateTime.now());
    final query = filter.query.trim().toLowerCase();

    return list.where((e) {
      if (range.start != null && e.transactionDate.isBefore(range.start!)) {
        return false;
      }
      if (range.end != null && !e.transactionDate.isBefore(range.end!)) {
        return false;
      }
      if (filter.categoryId != null && e.categoryId != filter.categoryId) {
        return false;
      }
      if (filter.paymentMethod != null &&
          e.paymentMethod != filter.paymentMethod) {
        return false;
      }
      if (filter.transactionType != null &&
          e.transactionType != filter.transactionType) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${e.title} ${e.notes ?? ''}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }
}
