import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_tables.dart';
import 'package:finora/core/sync/sync_writer.dart';
import 'package:finora/features/budget/data/models/budget_model.dart';
import 'package:finora/features/budget/data/sources/budget_sources.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl({
    required this.local,
    required this.sync,
    required SyncLocalStore store,
  }) : _store = store;

  final BudgetLocalSource local;
  final SyncWriter sync;
  final SyncLocalStore _store;

  @override
  Future<Either<Failure, List<Budget>>> getBudgets(int month, int year) async {
    try {
      await sync.prepareRead();
      final cached = local.readBudgets(month, year);
      return right(cached.map((e) => e.toEntity()).toList());
    } catch (e) {
      return left(LocalFailure(e.toString()));
    }
  }

  @override
  Stream<List<Budget>> watchBudgets(int month, int year) async* {
    yield (local.readBudgets(month, year)).map((e) => e.toEntity()).toList();
    yield* _store
        .box(SyncTables.budgets)
        .watch()
        .map((_) => (local.readBudgets(month, year)).map((e) => e.toEntity()).toList());
  }

  @override
  Future<Either<Failure, Budget>> addBudget(Budget budget) =>
      _write(budget, 'add');

  @override
  Future<Either<Failure, Budget>> updateBudget(Budget budget) =>
      _write(budget, 'update');

  Future<Either<Failure, Budget>> _write(Budget budget, String verb) async {
    try {
      final model = BudgetModel.fromEntity(budget);
      final stored = await sync.save(SyncTables.budgets, model.toCache());
      return right(BudgetModel.fromMap(stored).toEntity());
    } catch (e) {
      return left(LocalFailure('Failed to $verb budget: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteBudget(String id) async {
    try {
      await sync.remove(SyncTables.budgets, id);
      return right(unit);
    } catch (e) {
      return left(LocalFailure(e.toString()));
    }
  }
}
