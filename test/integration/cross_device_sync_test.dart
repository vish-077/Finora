
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finora/core/storage/app_database.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/network/network_info.dart';
import 'package:finora/core/sync/sync_cursor_store.dart';
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
import 'package:finora/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:finora/features/budget/data/sources/budget_sources.dart';
import 'package:finora/features/wallet/data/repositories/account_repository_impl.dart';
import 'package:finora/features/wallet/data/sources/account_sources.dart';
import 'package:finora/shared/enums/transaction_type.dart';

// ── Fake Firebase Auth ──────────────────────────────────────────────────────
// Firestore is simulated by FakeFirebaseFirestore (one instance shared by every
// "device"); auth only needs to report which uid is signed in.

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseUser extends Mock implements User {}

class FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}


void main() {
  late FakeFirebaseFirestore cloud;

  setUp(() {
    cloud = FakeFirebaseFirestore();
  });

  Future<List<Map<String, dynamic>>> cloudRows(String uid, String table) async {
    final snap = await cloud
        .collection(SyncTables.userRoot)
        .doc(uid)
        .collection(table)
        .get();
    return [for (final d in snap.docs) d.data()];
  }

  Future<(SyncEngine, SyncLocalStore, SyncQueue, SyncScopeStore, ExpenseRepositoryImpl, CategoryRepositoryImpl, void Function(String))> setupDevice({
    required String activeUserId,
  }) async {
    AppDatabase.initInMemory();
    for (final table in SyncTables.all) {
      await AppDatabase.openBox(table.box);
    }
    await AppDatabase.openBox(StorageBoxes.syncQueue);
    await AppDatabase.openBox(StorageBoxes.syncScope);
    await AppDatabase.openBox(StorageBoxes.settings);

    final store = SyncLocalStore();
    final queue = SyncQueue(AppDatabase.box(StorageBoxes.syncQueue));
    final scopes = SyncScopeStore(
      box: AppDatabase.box(StorageBoxes.syncScope),
      store: store,
      queue: queue,
    );
    final cursors = SyncCursorStore(AppDatabase.box(StorageBoxes.settings));

    var currentUid = activeUserId;
    final user = MockFirebaseUser();
    final auth = MockFirebaseAuth();
    when(() => user.uid).thenAnswer((_) => currentUid);
    when(() => auth.currentUser)
        .thenAnswer((_) => currentUid == SyncScope.guest ? null : user);
    when(auth.authStateChanges).thenAnswer((_) => const Stream<User?>.empty());

    final engine = SyncEngine(
      auth: auth,
      firestore: cloud,
      queue: queue,
      store: store,
      cursors: cursors,
      scopes: scopes,
      network: FakeNetworkInfo(),
    );

    final syncWriter = SyncWriter(
      queue: queue,
      store: store,
      engine: engine,
    );

    final expenseLocal = ExpenseLocalSourceImpl(AppDatabase.box(StorageBoxes.transactions));
    final categoryLocal = CategoryLocalSourceImpl(AppDatabase.box(StorageBoxes.categories));

    final categoryRepo = CategoryRepositoryImpl(
      local: categoryLocal,
      sync: syncWriter,
      store: store,
      currentUserId: () => currentUid,
    );

    final expenseRepo = ExpenseRepositoryImpl(
      local: expenseLocal,
      sync: syncWriter,
      store: store,
    );

    void setCurrentUser(String uid) {
      currentUid = uid;
    }

    return (engine, store, queue, scopes, expenseRepo, categoryRepo, setCurrentUser);
  }

  Expense expense(String id, String user, String title, double amount, String categoryId, PaymentMethod method) =>
      Expense(
        id: id,
        userId: user,
        title: title,
        amount: amount,
        categoryId: categoryId,
        paymentMethod: method,
        transactionType: TransactionType.expense,
        transactionDate: DateTime.now(),
      );

  test('cross-device cloud synchronization & fresh installation verification', () async {
    const accountA = 'user-account-A-uuid';
    const accountB = 'user-account-B-uuid';

    // -- STEP 1: Device A (Account A signs in and creates expenses) ----------
    final (engineA, _, _, scopesA, expenseRepoA, categoryRepoA, _) =
        await setupDevice(activeUserId: accountA);

    await scopesA.switchTo(accountA);
    await engineA.handleSignIn(accountA);

    final catsResultA = await categoryRepoA.getCategories();
    final catIdA = catsResultA.getOrElse((_) => []).first.id;

    await expenseRepoA.addExpense(
        expense('exp-111', accountA, 'Food', 500, catIdA, PaymentMethod.cash));
    await expenseRepoA.addExpense(
        expense('exp-222', accountA, 'Travel', 200, catIdA, PaymentMethod.cash));
    await expenseRepoA.addExpense(expense(
        'exp-333', accountA, 'Shopping', 1000, catIdA, PaymentMethod.debitCard));

    await engineA.syncNow(reason: 'device_A_push');

    final rowsA = await cloudRows(accountA, 'expenses');
    expect(rowsA.length, 3, reason: 'Device A expenses must be uploaded to Firestore');
    expect(rowsA.map((r) => r['title']), containsAll(['Food', 'Travel', 'Shopping']));
    expect(rowsA.every((r) => r['user_id'] == accountA), isTrue);
    expect(rowsA.every((r) => r['updated_at'] is Timestamp), isTrue,
        reason: 'updated_at must be stamped by the server');

    // -- STEP 2: Device B (fresh install - empty local storage) --------------
    final (engineB, _, _, scopesB, expenseRepoB, _, setUidB) =
        await setupDevice(activeUserId: SyncScope.guest);

    final initialB = await expenseRepoB.getExpenses();
    expect(initialB.getOrElse((_) => []), isEmpty,
        reason: 'Device B local storage must initially be empty');

    setUidB(accountA);
    await scopesB.switchTo(accountA);
    await engineB.handleSignIn(accountA);
    await engineB.syncNow(reason: 'device_B_pull');

    final listB = (await expenseRepoB.getExpenses()).getOrElse((_) => []);
    expect(listB.length, 3, reason: 'Device B must download all 3 expenses from Firestore');
    expect(listB.map((e) => e.title), containsAll(['Food', 'Travel', 'Shopping']));
    expect(listB.map((e) => e.amount), containsAll([500.0, 200.0, 1000.0]));

    // -- STEP 3: Add an expense on Device B & push it ------------------------
    await expenseRepoB.addExpense(
        expense('exp-444', accountA, 'Books', 300, catIdA, PaymentMethod.upi));
    await engineB.syncNow(reason: 'device_B_push');

    final rowsAfterB = await cloudRows(accountA, 'expenses');
    expect(rowsAfterB.length, 4, reason: 'Firestore must now hold 4 expenses for Account A');
    expect(rowsAfterB.map((r) => r['title']), contains('Books'));

    // -- STEP 4: Back on Device A: pull, then account transitions ------------
    final (engineA2, _, _, scopesA2, expenseRepoA2, categoryRepoA2, setUidA2) =
        await setupDevice(activeUserId: accountA);

    await scopesA2.switchTo(accountA);
    await engineA2.handleSignIn(accountA);
    await engineA2.syncNow(reason: 'device_A_pull_updates');

    final listA2 = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(listA2.length, 4, reason: 'Device A must pull the Books expense from Firestore');
    expect(listA2.map((e) => e.title), contains('Books'));

    // Logout -> guest mode
    await engineA2.handleSignOut();
    setUidA2(SyncScope.guest);
    await scopesA2.switchTo(SyncScope.guest);

    final guestList = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(guestList, isEmpty, reason: 'Guest mode must never see Account A expenses');

    final guestCats = (await categoryRepoA2.getCategories()).getOrElse((_) => []);
    await expenseRepoA2.addExpense(expense('guest-exp-99', SyncScope.guest,
        'Guest Coffee', 50, guestCats.first.id, PaymentMethod.cash));
    await engineA2.syncNow(reason: 'guest_sync_attempt');

    expect(await cloudRows(SyncScope.guest, 'expenses'), isEmpty,
        reason: 'Guest expenses must never be uploaded to cloud');

    // Login as Account B
    setUidA2(accountB);
    await scopesA2.switchTo(accountB);
    await engineA2.handleSignIn(accountB);

    final accountBList = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(accountBList, isEmpty, reason: 'Account B must not see Account A or Guest data');

    // Login as Account A again
    setUidA2(accountA);
    await scopesA2.switchTo(accountA);
    await engineA2.handleSignIn(accountA);

    final restoredList = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(restoredList.length, 4, reason: 'Logging back into Account A restores all 4 cloud expenses');
    expect(restoredList.map((e) => e.title), containsAll(['Food', 'Travel', 'Shopping', 'Books']));

    await AppDatabase.close();
  });
}
