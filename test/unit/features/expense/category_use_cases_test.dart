import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/use_cases/category_use_cases.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class _MockCategoryRepository implements CategoryRepository {
  Category? lastAdded;
  Category? lastUpdated;
  String? lastDeletedId;
  List<Category> categories = [];

  @override
  Future<Either<Failure, List<Category>>> getCategories() async =>
      right(categories);

  @override
  Future<Either<Failure, Category>> addCategory(Category category) async {
    lastAdded = category;
    return right(category);
  }

  @override
  Future<Either<Failure, Category>> updateCategory(Category category) async {
    lastUpdated = category;
    return right(category);
  }

  @override
  Future<Either<Failure, Unit>> deleteCategory(String id) async {
    lastDeletedId = id;
    return right(unit);
  }

  @override
  Stream<List<Category>> watchCategories() => Stream.value(categories);
}

void main() {
  late _MockCategoryRepository mockRepo;

  setUp(() {
    mockRepo = _MockCategoryRepository();
  });

  group('GetCategoriesUseCase', () {
    test('returns list from repository', () async {
      mockRepo.categories = const [
        Category(
          id: 'c1',
          userId: 'u1',
          name: 'Food',
          icon: 'restaurant',
          color: '#FF5722',
        ),
      ];
      final useCase = GetCategoriesUseCase(mockRepo);
      final result = await useCase();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Should be right'),
        (list) => expect(list.length, 1),
      );
    });
  });

  group('AddCategoryUseCase', () {
    test('returns ValidationFailure for empty name', () async {
      final useCase = AddCategoryUseCase(mockRepo);
      const category = Category(
        id: '',
        userId: 'u1',
        name: '',
        icon: 'restaurant',
        color: '#FF5722',
      );
      final result = await useCase(category);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('Should be left'),
      );
    });

    test('calls repository when name is valid', () async {
      final useCase = AddCategoryUseCase(mockRepo);
      const category = Category(
        id: '',
        userId: 'u1',
        name: 'Transport',
        icon: 'directions_car',
        color: '#3498DB',
      );
      final result = await useCase(category);
      expect(result.isRight(), isTrue);
      expect(mockRepo.lastAdded?.name, 'Transport');
    });
  });

  group('UpdateCategoryUseCase', () {
    test('returns ValidationFailure for whitespace-only name', () async {
      final useCase = UpdateCategoryUseCase(mockRepo);
      const category = Category(
        id: 'c1',
        userId: 'u1',
        name: '   ',
        icon: 'restaurant',
        color: '#FF5722',
      );
      final result = await useCase(category);
      expect(result.isLeft(), isTrue);
    });

    test('calls repository when valid', () async {
      final useCase = UpdateCategoryUseCase(mockRepo);
      const category = Category(
        id: 'c1',
        userId: 'u1',
        name: 'Dining',
        icon: 'restaurant',
        color: '#E91E63',
      );
      final result = await useCase(category);
      expect(result.isRight(), isTrue);
      expect(mockRepo.lastUpdated?.name, 'Dining');
    });
  });

  group('DeleteCategoryUseCase', () {
    test('calls repository delete', () async {
      final useCase = DeleteCategoryUseCase(mockRepo);
      final result = await useCase('cat-123');
      expect(result.isRight(), isTrue);
      expect(mockRepo.lastDeletedId, 'cat-123');
    });
  });
}
