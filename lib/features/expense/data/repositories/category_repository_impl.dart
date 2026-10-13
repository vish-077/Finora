import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_tables.dart';
import 'package:finora/core/sync/sync_writer.dart';
import 'package:finora/features/expense/data/models/category_model.dart';
import 'package:finora/features/expense/data/sources/category_sources.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required CategoryLocalSource local,
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

  final CategoryLocalSource _local;
  final SyncWriter _sync;
  final SyncLocalStore _store;
  final String Function() _currentUserId;
  final Uuid _uuid;

  @override
  Future<Either<Failure, List<Category>>> getCategories() async {
    try {
      await _sync.prepareRead();
      var list = _local.readAll();

      if (list.isEmpty) list = await _seedDefaults();

      return right(list);
    } catch (e) {
      return left(StorageReadFailure('Failed to read categories: $e'));
    }
  }

  @override
  Stream<List<Category>> watchCategories() async* {
    yield _local.readAll();
    yield* _store.box(SyncTables.categories).watch().map((_) => _local.readAll());
  }

  /// Seeds the starter set for a genuinely empty account.
  ///
  /// When signed in the seeds go through the sync queue, so every device ends
  /// up with the *same* category ids. (Seeding locally on each device was why
  /// the same expense pointed at a different category per device.)
  Future<List<CategoryModel>> _seedDefaults() async {
    final userId = _currentUserId();
    final defaults = defaultCategories(userId);

    for (final category in defaults) {
      if (userId == _anonymousUser) {
        await _local.upsert(category);
      } else {
        await _sync.save(SyncTables.categories, category.toCache());
      }
    }
    return defaults;
  }

  @override
  Future<Either<Failure, Category>> addCategory(Category category) async {
    final withId = category.id.isEmpty
        ? Category(
            id: _uuid.v4(),
            userId: category.userId,
            name: category.name,
            icon: category.icon,
            color: category.color,
            type: category.type,
          )
        : category;
    return _write(withId, 'add');
  }

  @override
  Future<Either<Failure, Category>> updateCategory(Category category) =>
      _write(category, 'update');

  Future<Either<Failure, Category>> _write(Category category, String verb) async {
    try {
      final model = CategoryModel.fromEntity(category);
      final stored = await _sync.save(SyncTables.categories, model.toCache());
      return right(CategoryModel.fromMap(stored));
    } catch (e) {
      return left(StorageWriteFailure('Failed to $verb category: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCategory(String id) async {
    try {
      await _sync.remove(SyncTables.categories, id);
      return right(unit);
    } catch (e) {
      return left(StorageWriteFailure('Failed to delete category: $e'));
    }
  }
}
