import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/storage/app_database.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/sync/sync_engine.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_scope.dart';
import 'package:finora/core/sync/sync_tables.dart';
import 'package:finora/core/sync/sync_writer.dart';
import 'package:finora/features/expense/data/repositories/category_repository_impl.dart';
import 'package:finora/features/expense/data/repositories/expense_repository_impl.dart';
import 'package:finora/features/expense/data/sources/category_sources.dart';
import 'package:finora/features/expense/data/sources/expense_local_source.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:finora/features/budget/data/sources/budget_sources.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/wallet/data/repositories/account_repository_impl.dart';
import 'package:finora/features/wallet/data/sources/account_sources.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class _FakeEngine implements SyncEngine {
  _FakeEngine({required this.isGuest});

  bool isGuest;

  @override
  bool get isGuestScope => isGuest;

  @override
  bool get canQueueUploads => !isGuest;

  @override
  void requestSync({String reason = 'requested'}) {}

  @override
  Future<void> ensureInitialSync() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late SyncLocalStore store;
  late SyncQueue queue;
  late SyncScopeStore scopes;
  late _FakeEngine engine;
  late SyncWriter syncWriter;

  late ExpenseLocalSource expenseLocal;
  late CategoryLocalSource categoryLocal;
  late BudgetLocalSource budgetLocal;
  late AccountLocalSource accountLocal;

  late ExpenseRepositoryImpl expenseRepo;
  late CategoryRepositoryImpl categoryRepo;
  late BudgetRepositoryImpl budgetRepo;
  late AccountRepositoryImpl accountRepo;

  late String activeUserId;

  const userA = 'user-aaa-111';
  const userB = 'user-bbb-222';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finora_isolation_test');
    AppDatabase.initInMemory();
    for (final table in SyncTables.all) {
      await AppDatabase.openBox(table.box);
    }
    await AppDatabase.openBox(StorageBoxes.syncQueue);
    await AppDatabase.openBox(StorageBoxes.syncScope);

    store = SyncLocalStore();
    queue = SyncQueue(AppDatabase.box(StorageBoxes.syncQueue));
    scopes = SyncScopeStore(
      box: AppDatabase.box(StorageBoxes.syncScope),
      store: store,
      queue: queue,
    );

    engine = _FakeEngine(isGuest: false);
    syncWriter = SyncWriter(queue: queue, store: store, engine: engine);

    expenseLocal = ExpenseLocalSourceImpl(AppDatabase.box(StorageBoxes.transactions));
    categoryLocal = CategoryLocalSourceImpl(AppDatabase.box(StorageBoxes.categories));
    budgetLocal = BudgetLocalSourceImpl(AppDatabase.box(StorageBoxes.budgets));
    accountLocal = AccountLocalSourceImpl(AppDatabase.box(StorageBoxes.wallets));

    activeUserId = userA;

    expenseRepo = ExpenseRepositoryImpl(
      local: expenseLocal,
      sync: syncWriter,
      store: store,
    );

    categoryRepo = CategoryRepositoryImpl(
      local: categoryLocal,
      sync: syncWriter,
      store: store,
      currentUserId: () => activeUserId,
    );

    budgetRepo = BudgetRepositoryImpl(
      local: budgetLocal,
      sync: syncWriter,
      store: store,
    );

    accountRepo = AccountRepositoryImpl(
      local: accountLocal,
      sync: syncWriter,
      store: store,
      currentUserId: () => activeUserId,
    );
  });

  tearDown(() async {
    await AppDatabase.deleteFromDisk();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('Data Isolation Integrity and Reactive Stream Validation', () {
    test('strictly isolates data between User A, User B, and Guest', () async {
      // 1. Initialise scopes under User A
      await scopes.switchTo(userA);
      engine.isGuest = false;
      activeUserId = userA;

      // Seed categories and accounts (implicitly done on first read or write)
      final catResultA = await categoryRepo.getCategories();
      expect(catResultA.isRight(), isTrue);
      final catsA = catResultA.getOrElse((_) => []);
      expect(catsA, isNotEmpty);

      final accResultA = await accountRepo.getAccounts();
      expect(accResultA.isRight(), isTrue);
      final accsA = accResultA.getOrElse((_) => []);
      expect(accsA, isNotEmpty);

      // Add a custom expense for User A
      final expenseA = Expense(
        id: '',
        userId: userA,
        title: 'User A Dinner',
        amount: 85.50,
        categoryId: catsA.first.id,
        paymentMethod: PaymentMethod.cash,
        transactionType: TransactionType.expense,
        transactionDate: DateTime.now(),
      );
      final addExpResultA = await expenseRepo.addExpense(expenseA);
      expect(addExpResultA.isRight(), isTrue);

      // Add a custom budget for User A
      final budgetA = Budget(
        id: 'budget-a-1',
        userId: userA,
        categoryId: catsA.first.id,
        month: 8,
        year: 2026,
        amount: 500,
      );
      final addBudgetResultA = await budgetRepo.addBudget(budgetA);
      expect(addBudgetResultA.isRight(), isTrue);

      // Setup watchers to listen to the streams and verify they update reactively
      final expenseList = <List<Expense>>[];
      final expenseSub = expenseRepo.watchExpenses().listen(expenseList.add);

      final budgetList = <List<Budget>>[];
      final budgetSub = budgetRepo.watchBudgets(8, 2026).listen(budgetList.add);

      // Give streams a microtask to emit their initial states
      await Future<void>.delayed(Duration.zero);

      expect(expenseList.last.length, 1);
      expect(expenseList.last.first.title, 'User A Dinner');
      expect(budgetList.last.length, 1);
      expect(budgetList.last.first.amount, 500);

      // ─── 2. Switch to GUEST Mode ───
      await scopes.switchTo(SyncScope.guest);
      engine.isGuest = true;
      activeUserId = SyncScope.guest;

      // Give streams a moment to process the clear/restore events
      await Future<void>.delayed(Duration.zero);

      // Verify that Guest sees NO data of User A
      expect(expenseList.last, isEmpty, reason: 'Guest must never see User A\'s expenses');
      expect(budgetList.last, isEmpty, reason: 'Guest must never see User A\'s budgets');

      // Seed categories/accounts for Guest
      final catResultGuest = await categoryRepo.getCategories();
      final catsGuest = catResultGuest.getOrElse((_) => []);
      expect(catsGuest, isNotEmpty);

      // Add a Guest-specific expense
      final expenseGuest = Expense(
        id: '',
        userId: SyncScope.guest,
        title: 'Guest Coffee',
        amount: 4.50,
        categoryId: catsGuest.first.id,
        paymentMethod: PaymentMethod.cash,
        transactionType: TransactionType.expense,
        transactionDate: DateTime.now(),
      );
      await expenseRepo.addExpense(expenseGuest);

      await Future<void>.delayed(Duration.zero);
      expect(expenseList.last.length, 1);
      expect(expenseList.last.first.title, 'Guest Coffee');

      // ─── 3. Switch to User B ───
      await scopes.switchTo(userB);
      engine.isGuest = false;
      activeUserId = userB;

      await Future<void>.delayed(Duration.zero);

      // Verify User B starts empty (no Guest data, no User A data)
      expect(expenseList.last, isEmpty, reason: 'User B must not see Guest or User A expenses');
      expect(budgetList.last, isEmpty, reason: 'User B must not see Guest or User A budgets');

      // Seed User B categories
      final catResultB = await categoryRepo.getCategories();
      final catsB = catResultB.getOrElse((_) => []);

      // Add User B expense
      final expenseB = Expense(
        id: '',
        userId: userB,
        title: 'User B Shopping',
        amount: 120.00,
        categoryId: catsB.first.id,
        paymentMethod: PaymentMethod.debitCard,
        transactionType: TransactionType.expense,
        transactionDate: DateTime.now(),
      );
      await expenseRepo.addExpense(expenseB);

      await Future<void>.delayed(Duration.zero);
      expect(expenseList.last.length, 1);
      expect(expenseList.last.first.title, 'User B Shopping');

      // ─── 4. Switch back to User A ───
      await scopes.switchTo(userA);
      engine.isGuest = false;
      activeUserId = userA;

      await Future<void>.delayed(Duration.zero);

      // Verify User A's data is fully restored and streams updated reactively
      expect(expenseList.last.length, 1);
      expect(expenseList.last.first.title, 'User A Dinner');
      expect(budgetList.last.length, 1);
      expect(budgetList.last.first.amount, 500);

      // ─── 5. Switch back to Guest ───
      await scopes.switchTo(SyncScope.guest);
      engine.isGuest = true;
      activeUserId = SyncScope.guest;

      await Future<void>.delayed(Duration.zero);

      // Verify Guest's data is fully restored and streams updated reactively
      expect(expenseList.last.length, 1);
      expect(expenseList.last.first.title, 'Guest Coffee');
      expect(budgetList.last, isEmpty);

      // Clean up subscriptions
      await expenseSub.cancel();
      await budgetSub.cancel();
    });
  });
}
