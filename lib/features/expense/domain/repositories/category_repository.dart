import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/category.dart';

abstract interface class CategoryRepository {
  Future<Either<Failure, List<Category>>> getCategories();

  Stream<List<Category>> watchCategories();

  Future<Either<Failure, Category>> addCategory(Category category);

  Future<Either<Failure, Category>> updateCategory(Category category);

  Future<Either<Failure, Unit>> deleteCategory(String id);
}
