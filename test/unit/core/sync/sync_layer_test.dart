import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/storage/app_database.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/sync/legacy_id_migration.dart';
import 'package:finora/core/sync/pending_op.dart';
import 'package:finora/core/sync/stable_id.dart';
import 'package:finora/core/sync/sync_cursor_store.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_tables.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finora_sync_test');
    AppDatabase.initInMemory();
    for (final table in SyncTables.all) {
      await AppDatabase.openBox(table.box);
    }
    await AppDatabase.openBox(StorageBoxes.syncQueue);
    await AppDatabase.openBox(StorageBoxes.settings);
  });

  tearDown(() async {
    await AppDatabase.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> expenseRow(String id, {String? categoryId}) => {
        'id': id,
        'user_id': 'u1',
        'title': 'Coffee',
        'amount': 120.0,
        'category_id': categoryId,
        'transaction_date': '2026-08-01T10:00:00.000Z',
      };

  group('SyncQueue', () {
    late SyncQueue queue;

    setUp(() => queue = SyncQueue(AppDatabase.box(StorageBoxes.syncQueue)));

    test('collapses repeated edits to one op per row', () async {
      await queue.enqueueUpsert(SyncTables.expenses, expenseRow('e1'));
      await queue.enqueueUpsert(
        SyncTables.expenses,
        {...expenseRow('e1'), 'title': 'Tea'},
      );

      expect(queue.length, 1);
      expect(queue.all().single.payload!['title'], 'Tea');
    });

    test('a delete supersedes a queued edit for the same row', () async {
      await queue.enqueueUpsert(SyncTables.expenses, expenseRow('e1'));
      await queue.enqueueDelete(SyncTables.expenses, 'e1');

      expect(queue.length, 1);
      expect(queue.all().single.type, SyncOpType.delete);
    });

    test('rejects rows without an id', () async {
      await queue.enqueueUpsert(SyncTables.expenses, {'user_id': 'u1'});
      expect(queue.length, 0);
    });

    test('ready() drains parents before children', () async {
      await queue.enqueueUpsert(SyncTables.expenses, expenseRow('e1'));
      await queue.enqueueUpsert(SyncTables.categories, {
        'id': 'c1',
        'user_id': 'u1',
        'name': 'Food',
      });

      final order =
          queue.ready(DateTime.now().toUtc()).map((op) => op.table).toList();
      expect(order, ['categories', 'expenses']);
    });

    test('a failed op backs off and is skipped until its window elapses',
        () async {
      await queue.enqueueUpsert(SyncTables.expenses, expenseRow('e1'));
      final op = queue.all().single;

      await queue.fail(op, Exception('boom'));

      expect(queue.length, 1, reason: 'the change must not be lost');
      expect(queue.ready(DateTime.now().toUtc()), isEmpty);
      expect(
        queue.ready(DateTime.now().toUtc().add(const Duration(hours: 1))),
        hasLength(1),
      );
    });

    test('pendingRowIds reports rows a pull must not overwrite', () async {
      await queue.enqueueUpsert(SyncTables.expenses, expenseRow('e1'));
      expect(queue.pendingRowIds(SyncTables.expenses), {'e1'});
      expect(queue.pendingRowIds(SyncTables.categories), isEmpty);
    });
  });

  group('SyncCursorStore', () {
    late SyncCursorStore cursors;

    setUp(() => cursors = SyncCursorStore(AppDatabase.box(StorageBoxes.settings)));

    test('cursors are per user and per table', () async {
      final stamp = DateTime.utc(2026, 8, 1, 12);
      await cursors.setCursor('u1', SyncTables.expenses, stamp);

      expect(cursors.cursor('u1', SyncTables.expenses), stamp);
      expect(cursors.cursor('u1', SyncTables.categories), isNull);
      expect(cursors.cursor('u2', SyncTables.expenses), isNull);
      expect(cursors.hasEverSynced('u1'), isTrue);
      expect(cursors.hasEverSynced('u2'), isFalse);
    });

    test('resetAll clears cursors and the remembered account', () async {
      await cursors.setLastUserId('u1');
      await cursors.setCursor('u1', SyncTables.expenses, DateTime.utc(2026));

      await cursors.resetAll();

      expect(cursors.lastUserId, isNull);
      expect(cursors.hasEverSynced('u1'), isFalse);
    });
  });

  group('stableId', () {
    test('is deterministic per user, so two devices agree on seeded rows', () {
      expect(stableId('category:u1:food'), stableId('category:u1:food'));
      expect(isUuid(stableId('category:u1:food')), isTrue);
    });

    test('differs per account', () {
      expect(stableId('category:u1:food'),
          isNot(stableId('category:u2:food')));
    });
  });

  group('LegacyIdMigration', () {
    late SyncLocalStore store;
    late SyncQueue queue;
    late LegacyIdMigration migration;

    setUp(() {
      store = SyncLocalStore();
      queue = SyncQueue(AppDatabase.box(StorageBoxes.syncQueue));
      migration = LegacyIdMigration(
        settingsBox: AppDatabase.box(StorageBoxes.settings),
        store: store,
        queue: queue,
      );
    });

    test('rewrites non-uuid seed ids and repoints referencing expenses',
        () async {
      await store.put(SyncTables.categories, {
        'id': 'default-food',
        'user_id': 'u1',
        'name': 'Food',
      });
      await store.put(
        SyncTables.expenses,
        expenseRow('e1', categoryId: 'default-food'),
      );

      await migration.run();

      final expectedId = stableId('category:u1:food');
      expect(store.read(SyncTables.categories, 'default-food'), isNull);
      expect(store.read(SyncTables.categories, expectedId), isNotNull);
      expect(
        store.read(SyncTables.expenses, 'e1')!['category_id'],
        expectedId,
        reason: 'the expense must follow its category to the new id',
      );
    });

    test('queues existing local rows so they are adopted into the account',
        () async {
      const id = '11111111-2222-4333-8444-555555555555';
      await store.put(SyncTables.expenses, expenseRow(id));

      await migration.run();

      expect(queue.pendingRowIds(SyncTables.expenses), {id});
    });

    test('leaves rows whose id Postgres would reject on the device', () async {
      await store.put(SyncTables.expenses, expenseRow('not-a-uuid'));

      await migration.run();

      expect(queue.length, 0);
      expect(store.read(SyncTables.expenses, 'not-a-uuid'), isNotNull);
    });

    test('runs only once', () async {
      await migration.run();
      await store.put(SyncTables.expenses, expenseRow('e2'));
      await migration.run();

      expect(queue.length, 0, reason: 'the second run must be a no-op');
    });
  });

  group('SyncLocalStore', () {
    test('reads rows written as JSON strings by the feature local sources', () {
      final store = SyncLocalStore();
      AppDatabase.box(SyncTables.expenses.box)
          .put('e1', jsonEncode(expenseRow('e1')));

      expect(store.readAll(SyncTables.expenses), hasLength(1));
      expect(store.read(SyncTables.expenses, 'e1')!['title'], 'Coffee');
    });

    test('clearAll wipes every mirrored table', () async {
      final store = SyncLocalStore();
      await store.put(SyncTables.expenses, expenseRow('e1'));
      await store.put(
          SyncTables.categories, {'id': 'c1', 'user_id': 'u1', 'name': 'Food'});

      await store.clearAll();

      expect(store.readAll(SyncTables.expenses), isEmpty);
      expect(store.readAll(SyncTables.categories), isEmpty);
    });
  });
}
