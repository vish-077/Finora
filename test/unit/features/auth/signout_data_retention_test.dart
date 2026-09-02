import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:finora/core/constants/hive_constants.dart';
import 'package:finora/features/auth/data/sources/auth_local_source.dart';

void main() {
  late Directory tempDir;
  late AuthLocalSourceImpl source;

  const dataBoxes = [
    HiveBoxes.transactions,
    HiveBoxes.categories,
    HiveBoxes.budgets,
    HiveBoxes.wallets,
    HiveBoxes.goals,
  ];

  const clearedBoxes = [
    HiveBoxes.notifications,
    HiveBoxes.receipts,
    HiveBoxes.reports,
  ];

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('finora_signout_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    for (final name in [
      ...dataBoxes,
      ...clearedBoxes,
      HiveBoxes.syncQueue,
      HiveBoxes.aiHistory,
      HiveBoxes.userProfile,
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox<dynamic>(name);
      await Hive.box<dynamic>(name).put('seed', {'id': 'seed'});
    }
    source = AuthLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.userProfile));
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
          Hive.box<dynamic>(name).isNotEmpty,
          isTrue,
          reason: '$name must survive sign-out — SyncEngine owns its lifecycle',
        );
      }
    });

    test('leaves the pending-upload outbox intact', () async {
      await source.clearAllUserData();

      expect(
        Hive.box<dynamic>(HiveBoxes.syncQueue).isNotEmpty,
        isTrue,
        reason: 'unsent changes must upload on the next sign-in',
      );
    });

    test('leaves AI chat history intact', () async {
      await source.clearAllUserData();
      expect(Hive.box<dynamic>(HiveBoxes.aiHistory).isNotEmpty, isTrue);
    });

    test('still clears device-local, re-derivable caches', () async {
      await source.clearAllUserData();

      for (final name in clearedBoxes) {
        expect(
          Hive.box<dynamic>(name).isEmpty,
          isTrue,
          reason: '$name is device-local and should not linger',
        );
      }
    });
  });
}
