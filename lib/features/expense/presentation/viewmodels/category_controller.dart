import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_providers.dart';
import 'package:finora/shared/enums/transaction_type.dart';

part 'category_controller.g.dart';

@riverpod
class CategoryController extends _$CategoryController {
  @override
  FutureOr<List<Category>> build() {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    if (categoriesAsync.hasValue) {
      return categoriesAsync.value!;
    }
    return _load();
  }

  Future<List<Category>> _load() async {
    final result = await ref.read(getCategoriesUseCaseProvider)();
    return result.fold((failure) => throw failure, (list) => list);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  String get _userId =>
      ref.read(authControllerProvider).user?.id ?? 'local-user';

  Future<Failure?> addCategory({
    required String name,
    required String icon,
    required String color,
    required TransactionType type,
  }) async {
    final category = Category(
      id: '',
      userId: _userId,
      name: name,
      icon: icon,
      color: color,
      type: type,
    );
    final result = await ref.read(addCategoryUseCaseProvider)(category);
    return result.fold((f) => f, (_) {
      unawaited(refresh());
      return null;
    });
  }

  Future<Failure?> updateCategory(Category category) async {
    final result = await ref.read(updateCategoryUseCaseProvider)(category);
    return result.fold((f) => f, (_) {
      unawaited(refresh());
      return null;
    });
  }

  Future<Failure?> deleteCategory(String id) async {
    final result = await ref.read(deleteCategoryUseCaseProvider)(id);
    return result.fold((f) => f, (_) {
      unawaited(refresh());
      return null;
    });
  }
}
