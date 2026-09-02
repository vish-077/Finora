import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';

class GetCategoriesUseCase {
  const GetCategoriesUseCase(this._repo);
  final CategoryRepository _repo;

  Future<Either<Failure, List<Category>>> call() => _repo.getCategories();
}

class AddCategoryUseCase {
  const AddCategoryUseCase(this._repo);
  final CategoryRepository _repo;

  Future<Either<Failure, Category>> call(Category category) {
    if (category.name.trim().isEmpty) {
      return Future.value(
        left(const ValidationFailure('Category name is required',
            field: 'name')),
      );
    }
    return _repo.addCategory(category);
  }
}

class UpdateCategoryUseCase {
  const UpdateCategoryUseCase(this._repo);
  final CategoryRepository _repo;

  Future<Either<Failure, Category>> call(Category category) {
    if (category.name.trim().isEmpty) {
      return Future.value(
        left(const ValidationFailure('Category name is required',
            field: 'name')),
      );
    }
    return _repo.updateCategory(category);
  }
}

class DeleteCategoryUseCase {
  const DeleteCategoryUseCase(this._repo);
  final CategoryRepository _repo;

  Future<Either<Failure, Unit>> call(String id) => _repo.deleteCategory(id);
}
