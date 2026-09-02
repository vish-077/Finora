import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';

import 'package:finora/core/constants/hive_constants.dart';
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

// ── In-Memory Cloud Database (Simulating Supabase PostgreSQL + RLS) ─────────

class CloudDatabase {
  final Map<String, List<Map<String, dynamic>>> tables = {};

  List<Map<String, dynamic>> getTable(String name) =>
      tables.putIfAbsent(name, () => []);

  Map<String, dynamic> upsert(String tableName, Map<String, dynamic> payload) {
    final list = getTable(tableName);
    final id = payload['id'] as String;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final row = Map<String, dynamic>.from(payload);
    row['created_at'] ??= nowIso;
    row['updated_at'] = nowIso;

    final idx = list.indexWhere((r) => r['id'] == id);
    if (idx >= 0) {
      list[idx] = row;
    } else {
      list.add(row);
    }
    return row;
  }

  List<Map<String, dynamic>> select({
    required String tableName,
    required String userId,
    String? gtUpdatedAt,
  }) {
    final list = getTable(tableName);
    return list.where((row) {
      if (row['user_id'] != userId) return false;
      if (gtUpdatedAt != null) {
        final rowUpdated = DateTime.tryParse('${row['updated_at']}');
        final filterUpdated = DateTime.tryParse(gtUpdatedAt);
        if (rowUpdated != null && filterUpdated != null) {
          if (!rowUpdated.isAfter(filterUpdated)) return false;
        }
      }
      return true;
    }).map((r) => Map<String, dynamic>.from(r)).toList();
  }
}

// ── Mock Supabase Classes ───────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockRealtimeChannel extends Mock implements RealtimeChannel {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockFilterBuilder extends Mock implements PostgrestFilterBuilder<PostgrestList> {}
class MockSingleTransformBuilder extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>?> {}
class MockListTransformBuilder extends Mock implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}
class FakeRealtimeChannel extends Fake implements RealtimeChannel {}

class FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
}

void main() {
  late Directory rootDir;
  late CloudDatabase cloudDb;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(FakeRealtimeChannel());
    registerFallbackValue(PostgresChangeEvent.all);
  });

  setUp(() async {
    rootDir = await Directory.systemTemp.createTemp('finora_cross_device');
    cloudDb = CloudDatabase();
  });

  tearDown(() async {
    if (rootDir.existsSync()) await rootDir.delete(recursive: true);
  });

  Future<(SyncEngine, SyncLocalStore, SyncQueue, SyncScopeStore, ExpenseRepositoryImpl, CategoryRepositoryImpl, void Function(String))> setupDevice({
    required Directory tempDir,
    required String activeUserId,
    required CloudDatabase cloud,
  }) async {
    Hive.init(tempDir.path);
    for (final table in SyncTables.all) {
      await Hive.openBox<dynamic>(table.box);
    }
    await Hive.openBox<dynamic>(HiveBoxes.syncQueue);
    await Hive.openBox<dynamic>(HiveBoxes.syncScope);
    await Hive.openBox<dynamic>(HiveBoxes.settings);

    final store = SyncLocalStore();
    final queue = SyncQueue(Hive.box<dynamic>(HiveBoxes.syncQueue));
    final scopes = SyncScopeStore(
      box: Hive.box<dynamic>(HiveBoxes.syncScope),
      store: store,
      queue: queue,
    );
    final cursors = SyncCursorStore(Hive.box<dynamic>(HiveBoxes.settings));

    final client = MockSupabaseClient();
    final auth = MockGoTrueClient();
    var currentUid = activeUserId;
    final user = MockUser();

    when(() => user.id).thenAnswer((_) => currentUid);
    when(() => auth.currentUser).thenAnswer((_) => currentUid == SyncScope.guest ? null : user);
    when(() => auth.onAuthStateChange)
        .thenAnswer((_) => Stream.value(AuthState(AuthChangeEvent.signedIn, null)));
    when(() => client.auth).thenReturn(auth);

    final channel = MockRealtimeChannel();
    when(() => channel.onPostgresChanges(
          event: any(named: 'event'),
          schema: any(named: 'schema'),
          table: any(named: 'table'),
          filter: any(named: 'filter'),
          callback: any(named: 'callback'),
        )).thenReturn(channel);
    when(() => channel.subscribe(any(), any())).thenReturn(channel);

    when(() => client.channel(any())).thenReturn(channel);
    when(() => client.removeChannel(any())).thenAnswer((_) async => 'ok');

    // Pre-wire query builders per table
    for (final syncTable in SyncTables.all) {
      final tableName = syncTable.remote;
      final qb = MockSupabaseQueryBuilder();
      when(() => client.from(tableName)).thenAnswer((_) => qb);

      // --- UPSERT STREAM ---
      final upsertFilter = MockFilterBuilder();
      final upsertSingle = MockSingleTransformBuilder();

      when(() => qb.upsert(any())).thenAnswer((inv) {
        final payload = Map<String, dynamic>.from(inv.positionalArguments[0] as Map);
        final updatedRow = cloud.upsert(tableName, payload);

        when(() => upsertSingle.then<dynamic>(any(), onError: any(named: 'onError')))
            .thenAnswer((invThen) {
          final fn = invThen.positionalArguments[0] as Function;
          return Future.value(fn(updatedRow));
        });

        return upsertFilter;
      });

      when(() => upsertFilter.select(any())).thenAnswer((_) => upsertFilter);
      when(() => upsertFilter.maybeSingle()).thenAnswer((_) => upsertSingle);

      // --- SELECT / PULL STREAM ---
      final selectFilter = MockFilterBuilder();
      when(() => qb.select(any())).thenAnswer((_) => selectFilter);

      final userFilter = MockFilterBuilder();
      final gtFilter = MockFilterBuilder();
      final listTransformGt = MockListTransformBuilder();
      final listTransformDirect = MockListTransformBuilder();

      when(() => selectFilter.eq('user_id', any())).thenAnswer((invEq) {
        final uId = invEq.positionalArguments[1] as String;

        when(() => userFilter.gt('updated_at', any())).thenAnswer((invGt) {
          final gtVal = invGt.positionalArguments[1] as String;

          when(() => gtFilter.order('updated_at', ascending: any(named: 'ascending'))).thenAnswer((_) => listTransformGt);
          when(() => listTransformGt.limit(any())).thenAnswer((_) => listTransformGt);
          when(() => listTransformGt.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((invThen) {
            final fn = invThen.positionalArguments[0] as Function;
            final list = cloud.select(tableName: tableName, userId: uId, gtUpdatedAt: gtVal);
            return Future.value(fn(list));
          });

          return gtFilter;
        });

        when(() => userFilter.order('updated_at', ascending: any(named: 'ascending'))).thenAnswer((_) => listTransformDirect);
        when(() => listTransformDirect.limit(any())).thenAnswer((_) => listTransformDirect);
        when(() => listTransformDirect.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((invThen) {
          final fn = invThen.positionalArguments[0] as Function;
          final list = cloud.select(tableName: tableName, userId: uId);
          return Future.value(fn(list));
        });

        return userFilter;
      });
    }

    final engine = SyncEngine(
      client: client,
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

    final expenseLocal = ExpenseLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.transactions));
    final categoryLocal = CategoryLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.categories));

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

  test('cross-device cloud synchronization & fresh installation verification', () async {
    const accountA = 'user-account-A-uuid';
    const accountB = 'user-account-B-uuid';

    // ── STEP 1: Device A (Account A registers/logs in and creates expenses) ──
    final dirA = Directory('${rootDir.path}/device_A')..createSync();

    final (engineA, storeA, queueA, scopesA, expenseRepoA, categoryRepoA, setUidA) = await setupDevice(
      tempDir: dirA,
      activeUserId: accountA,
      cloud: cloudDb,
    );

    await scopesA.switchTo(accountA);
    await engineA.handleSignIn(accountA);

    // Seed categories for Account A
    final catsResultA = await categoryRepoA.getCategories();
    final catIdA = catsResultA.getOrElse((_) => []).first.id;

    // Add 3 expenses on Device A: ₹500 Food, ₹200 Travel, ₹1000 Shopping
    final exp1 = Expense(
      id: 'exp-111',
      userId: accountA,
      title: 'Food',
      amount: 500.0,
      categoryId: catIdA,
      paymentMethod: PaymentMethod.cash,
      transactionType: TransactionType.expense,
      transactionDate: DateTime.now(),
    );
    final exp2 = Expense(
      id: 'exp-222',
      userId: accountA,
      title: 'Travel',
      amount: 200.0,
      categoryId: catIdA,
      paymentMethod: PaymentMethod.cash,
      transactionType: TransactionType.expense,
      transactionDate: DateTime.now(),
    );
    final exp3 = Expense(
      id: 'exp-333',
      userId: accountA,
      title: 'Shopping',
      amount: 1000.0,
      categoryId: catIdA,
      paymentMethod: PaymentMethod.debitCard,
      transactionType: TransactionType.expense,
      transactionDate: DateTime.now(),
    );

    await expenseRepoA.addExpense(exp1);
    await expenseRepoA.addExpense(exp2);
    await expenseRepoA.addExpense(exp3);

    // Push changes from Device A to Supabase cloud
    await engineA.syncNow(reason: 'device_A_push');

    // Confirm that ₹500, ₹200, ₹1000 are uploaded to Supabase PostgreSQL table with user_id = accountA
    final cloudRows = cloudDb.getTable('expenses').where((r) => r['user_id'] == accountA).toList();
    expect(cloudRows.length, 3, reason: 'Device A expenses must be uploaded to Supabase cloud table');
    expect(cloudRows.map((r) => r['title']), containsAll(['Food', 'Travel', 'Shopping']));
    expect(cloudRows.every((r) => r['user_id'] == accountA), isTrue);

    await Hive.close();

    // ── STEP 2: Device B (Fresh Installation - clean empty Hive) ────────────
    final dirB = Directory('${rootDir.path}/device_B')..createSync();

    final (engineB, storeB, queueB, scopesB, expenseRepoB, categoryRepoB, setUidB) = await setupDevice(
      tempDir: dirB,
      activeUserId: SyncScope.guest,
      cloud: cloudDb,
    );

    // Verify Device B starts with empty Hive local storage
    final initialB = await expenseRepoB.getExpenses();
    expect(initialB.getOrElse((_) => []), isEmpty, reason: 'Device B Hive must initially be empty');

    // Login with Account A on Device B
    setUidB(accountA);
    await scopesB.switchTo(accountA);
    await engineB.handleSignIn(accountA);
    await engineB.syncNow(reason: 'device_B_pull');

    // Verify that Device B downloads Account A's expenses from Supabase
    final downloadedB = await expenseRepoB.getExpenses();
    final listB = downloadedB.getOrElse((_) => []);
    expect(listB.length, 3, reason: 'Device B must download all 3 expenses from Supabase');
    expect(listB.map((e) => e.title), containsAll(['Food', 'Travel', 'Shopping']));
    expect(listB.map((e) => e.amount), containsAll([500.0, 200.0, 1000.0]));

    // ── STEP 3: Add new expense on Device B & sync back to Device A ─────────
    final exp4 = Expense(
      id: 'exp-444',
      userId: accountA,
      title: 'Books',
      amount: 300.0,
      categoryId: catIdA,
      paymentMethod: PaymentMethod.upi,
      transactionType: TransactionType.expense,
      transactionDate: DateTime.now(),
    );
    await expenseRepoB.addExpense(exp4);
    await engineB.syncNow(reason: 'device_B_push');

    // Verify ₹300 Books expense is uploaded to Supabase with user_id = accountA
    final cloudRowsAfterB = cloudDb.getTable('expenses').where((r) => r['user_id'] == accountA).toList();
    expect(cloudRowsAfterB.length, 4, reason: 'Supabase must now hold 4 expenses for Account A');
    expect(cloudRowsAfterB.map((r) => r['title']), contains('Books'));

    await Hive.close();

    // ── STEP 4: Return to Device A & test Account Transitions/Isolation ────
    final (engineA2, storeA2, queueA2, scopesA2, expenseRepoA2, categoryRepoA2, setUidA2) = await setupDevice(
      tempDir: dirA,
      activeUserId: accountA,
      cloud: cloudDb,
    );

    await scopesA2.switchTo(accountA);
    await engineA2.handleSignIn(accountA);
    await engineA2.syncNow(reason: 'device_A_pull_updates');

    // Confirm Device A now receives the ₹300 Books expense created on Device B
    final listA2 = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(listA2.length, 4, reason: 'Device A must pull the ₹300 Books expense from Supabase');
    expect(listA2.map((e) => e.title), contains('Books'));

    // Test Logout -> Guest Mode
    await engineA2.handleSignOut();
    setUidA2(SyncScope.guest);
    await scopesA2.switchTo(SyncScope.guest);

    final guestList = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(guestList, isEmpty, reason: 'Guest mode must never see Account A expenses');

    // Guest adds a local expense
    final guestCats = (await categoryRepoA2.getCategories()).getOrElse((_) => []);
    final guestExp = Expense(
      id: 'guest-exp-99',
      userId: SyncScope.guest,
      title: 'Guest Coffee',
      amount: 50.0,
      categoryId: guestCats.first.id,
      paymentMethod: PaymentMethod.cash,
      transactionType: TransactionType.expense,
      transactionDate: DateTime.now(),
    );
    await expenseRepoA2.addExpense(guestExp);
    await engineA2.syncNow(reason: 'guest_sync_attempt');

    // Confirm Guest expense was NOT uploaded to Supabase
    final cloudGuestRows = cloudDb.getTable('expenses').where((r) => r['user_id'] == SyncScope.guest).toList();
    expect(cloudGuestRows, isEmpty, reason: 'Guest expenses must never be uploaded to cloud');

    // Test Login Account B
    setUidA2(accountB);
    await scopesA2.switchTo(accountB);
    await engineA2.handleSignIn(accountB);

    final accountBList = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(accountBList, isEmpty, reason: 'Account B must not see Account A or Guest data');

    // Test Login Account A again
    setUidA2(accountA);
    await scopesA2.switchTo(accountA);
    await engineA2.handleSignIn(accountA);

    final restoredList = (await expenseRepoA2.getExpenses()).getOrElse((_) => []);
    expect(restoredList.length, 4, reason: 'Logging back into Account A restores all 4 cloud expenses');
    expect(restoredList.map((e) => e.title), containsAll(['Food', 'Travel', 'Shopping', 'Books']));

    await Hive.close();
  });
}
