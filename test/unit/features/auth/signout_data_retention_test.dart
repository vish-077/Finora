import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/storage/app_database.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/features/auth/data/sources/auth_local_source.dart';

void main() {
  late Directory tempDir;
  late AuthLocalSourceImpl source;

  const dataBoxes = [
    StorageBoxes.transactions,
    StorageBoxes.categories,
    StorageBoxes.budgets,
    StorageBoxes.wallets,
    StorageBoxes.goals,
  ];

  const clearedBoxes = [
    StorageBoxes.notifications,
    StorageBoxes.receipts,
    StorageBoxes.reports,
  ];

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('finora_signout_test');
    AppDatabase.initInMemory();
  });

  setUp(() async {
    for (final name in [
      ...dataBoxes,
      ...clearedBoxes,
      StorageBoxes.syncQueue,
      StorageBoxes.aiHistory,
      StorageBoxes.userProfile,
    ]) {
      if (!AppDatabase.isBoxOpen(name)) await AppDatabase.openBox(name);
      await AppDatabase.box(name).put('seed', {'id': 'seed'});
    }
    source = AuthLocalSourceImpl(AppDatabase.box(StorageBoxes.userProfile));
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('clearAllUserData on sign-out', () {
    // Regression: this used to clear the synced tables AND the outbox. On a
    // device whose writes had never reached the server (unreachable backend),
    // every expense the user had entered was destroyed, so signing back in
    // showed zero balance and no transactions.
    test('leaves synced financial data intact', () async {
      await source.clearAllUserData();

      for (final name in dataBoxes) {
        expect(
          AppDatabase.box(name).isNotEmpty,
          isTrue,
          reason: '$name must survive sign-out — SyncEngine owns its lifecycle',
        );
      }
    });

    test('leaves the pending-upload outbox intact', () async {
      await source.clearAllUserData();

      expect(
        AppDatabase.box(StorageBoxes.syncQueue).isNotEmpty,
        isTrue,
        reason: 'unsent changes must upload on the next sign-in',
      );
    });

    test('leaves AI chat history intact', () async {
      await source.clearAllUserData();
      expect(AppDatabase.box(StorageBoxes.aiHistory).isNotEmpty, isTrue);
    });

    test('still clears device-local, re-derivable caches', () async {
      await source.clearAllUserData();

      for (final name in clearedBoxes) {
        expect(
          AppDatabase.box(name).isEmpty,
          isTrue,
          reason: '$name is device-local and should not linger',
        );
      }
    });
  });
}
