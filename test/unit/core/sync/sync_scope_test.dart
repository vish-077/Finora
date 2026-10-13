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

/// Stands in for the engine so the writer's upload gate can be exercised
/// without a Firebase session.
class _FakeEngine implements SyncEngine {
  _FakeEngine({required this.guest});

  final bool guest;
  int syncRequests = 0;

  @override
  bool get isGuestScope => guest;

  @override
  bool get canQueueUploads => !guest;

  @override
  void requestSync({String reason = 'requested'}) => syncRequests++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late SyncLocalStore store;
  late SyncQueue queue;
  late SyncScopeStore scopes;

  const userA = '11111111-1111-4111-8111-111111111111';
  const userB = '22222222-2222-4222-8222-222222222222';

  Map<String, dynamic> expense(String id, String userId, double amount) => {
        'id': id,
        'user_id': userId,
        'title': 'Expense $id',
        'amount': amount,
        'transaction_date': '2026-08-01T10:00:00.000Z',
      };

  List<double> amounts() =>
      store.readAll(SyncTables.expenses).map((r) => r['amount'] as double).toList();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finora_scope_test');
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
  });

  tearDown(() async {
    await AppDatabase.deleteFromDisk();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('SyncScopeStore', () {
    test('adopt() claims existing boxes without destroying them', () async {
      await store.put(SyncTables.expenses, expense('e1', userA, 500));

      await scopes.adopt(userA);

      expect(scopes.activeOwner, userA);
      expect(amounts(), [500]);
    });

    test('adopt() is a no-op once an owner is set', () async {
      await scopes.switchTo(userA);
      await scopes.adopt(userB);
      expect(scopes.activeOwner, userA);
    });

    // Test C — guest must never see the previous account's expenses.
    test('guest sees nothing after an authenticated user is scoped out',
        () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));

      await scopes.switchTo(SyncScope.guest);

      expect(amounts(), isEmpty);
      expect(scopes.isGuestActive, isTrue);
    });

    // Tests A and E — signing back in restores this device's copy.
    test('signing back in restores the same account rows', () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));

      await scopes.switchTo(SyncScope.guest);
      await scopes.switchTo(userA);

      expect(amounts(), [500]);
    });

    // Test D — two users on one device.
    test('user B never sees user A rows, and A gets them back', () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));

      await scopes.switchTo(userB);
      expect(amounts(), isEmpty);

      await store.put(SyncTables.expenses, expense('e2', userB, 1000));
      expect(amounts(), [1000]);

      await scopes.switchTo(userA);
      expect(amounts(), [500]);

      await scopes.switchTo(userB);
      expect(amounts(), [1000]);
    });

    // Test F — guest entries must not leak into an account.
    test('guest expenses do not appear for a user who signs in', () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));

      await scopes.switchTo(SyncScope.guest);
      await store.put(SyncTables.expenses, expense('g1', SyncScope.guest, 300));

      await scopes.switchTo(userA);

      expect(amounts(), [500], reason: 'the guest 300 must not be merged in');
    });

    test('guest keeps its own entries across guest sessions', () async {
      await scopes.switchTo(SyncScope.guest);
      await store.put(SyncTables.expenses, expense('g1', SyncScope.guest, 300));

      await scopes.switchTo(userA);
      await scopes.switchTo(SyncScope.guest);

      expect(amounts(), [300]);
    });

    test('unsent writes are stashed on sign-out and restored on sign-in',
        () async {
      await scopes.switchTo(userA);
      await queue.enqueueUpsert(SyncTables.expenses, expense('e1', userA, 500));
      expect(queue.length, 1);

      await scopes.switchTo(SyncScope.guest);
      expect(queue.length, 0, reason: 'guest must not inherit A\'s outbox');

      await scopes.switchTo(userA);
      expect(queue.length, 1);
      expect(queue.all().single.rowId, 'e1');
    });

    test('a guest outbox never carries into an account', () async {
      await scopes.switchTo(SyncScope.guest);
      await queue.enqueueUpsert(
        SyncTables.expenses,
        expense('g1', SyncScope.guest, 300),
      );

      await scopes.switchTo(userA);

      expect(queue.length, 0);
    });

    test('switchTo the active owner is a no-op', () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));

      expect(await scopes.switchTo(userA), isFalse);
      expect(amounts(), [500]);
    });

    // Firebase replays the current user on subscribe just as startup calls
    // handleSignIn, so two swaps to the same owner can be in flight at once.
    test('concurrent switches to the same owner do not lose rows', () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));
      await scopes.switchTo(SyncScope.guest);

      await Future.wait([scopes.switchTo(userA), scopes.switchTo(userA)]);

      expect(scopes.activeOwner, userA);
      expect(amounts(), [500]);
    });

    test('forget() drops only the stashed local copy', () async {
      await scopes.switchTo(userA);
      await store.put(SyncTables.expenses, expense('e1', userA, 500));
      await scopes.switchTo(SyncScope.guest);

      await scopes.forget(userA);
      await scopes.switchTo(userA);

      expect(amounts(), isEmpty);
    });
  });

  group('SyncWriter upload gate', () {
    test('guest writes stay local and are never queued', () async {
      final engine = _FakeEngine(guest: true);
      final writer =
          SyncWriter(queue: queue, store: store, engine: engine);

      await writer.save(
        SyncTables.expenses,
        expense('g1', SyncScope.guest, 300),
      );

      expect(amounts(), [300], reason: 'guest still gets local persistence');
      expect(queue.length, 0, reason: 'nothing may be uploaded for a guest');
      expect(engine.syncRequests, 0);
    });

    test('guest deletes are not queued as cloud tombstones', () async {
      final engine = _FakeEngine(guest: true);
      final writer =
          SyncWriter(queue: queue, store: store, engine: engine);

      await writer.save(
        SyncTables.expenses,
        expense('g1', SyncScope.guest, 300),
      );
      await writer.remove(SyncTables.expenses, 'g1');

      expect(amounts(), isEmpty);
      expect(queue.length, 0);
    });

    test('authenticated writes are queued and trigger a sync', () async {
      final engine = _FakeEngine(guest: false);
      final writer =
          SyncWriter(queue: queue, store: store, engine: engine);

      await writer.save(SyncTables.expenses, expense('e1', userA, 500));

      expect(amounts(), [500]);
      expect(queue.length, 1);
      expect(engine.syncRequests, 1);
    });
  });
}
