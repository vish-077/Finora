import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/storage/app_database.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/features/profile/data/services/avatar_service.dart';

void main() {
  late AvatarService service;
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('finora_avatar_test');
    AppDatabase.initInMemory();
  });

  setUp(() async {
    if (!AppDatabase.isBoxOpen(StorageBoxes.settings)) {
      await AppDatabase.openBox(StorageBoxes.settings);
    }
    await AppDatabase.box(StorageBoxes.settings).clear();
    service = AvatarService();
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Writes a real file and registers it as [userId]'s avatar, standing in for
  /// a completed pick (which needs a platform picker).
  File _seedAvatar(String userId) {
    final file = File('${tempDir.path}/avatar_$userId.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    AppDatabase.box(StorageBoxes.settings)
        .put('avatar_path_$userId', file.path);
    return file;
  }

  group('AvatarService per-account isolation', () {
    // Regression: a single device-wide 'avatar_path' key meant a picture added
    // by one account appeared on every other account, including guest mode.
    test('one account\'s avatar is not visible to another', () {
      _seedAvatar('user-abc');

      expect(service.currentAvatar('user-abc'), isNotNull);
      expect(service.currentAvatar('local-user'), isNull);
      expect(service.currentAvatar('other-user'), isNull);
    });

    test('guest and signed-in users keep separate pictures', () {
      final signedIn = _seedAvatar('user-abc');
      final guest = _seedAvatar('local-user');

      expect(service.currentAvatar('user-abc')!.path, signedIn.path);
      expect(service.currentAvatar('local-user')!.path, guest.path);
      expect(
        service.currentAvatar('user-abc')!.path,
        isNot(service.currentAvatar('local-user')!.path),
      );
    });

    test('remove only clears the targeted account', () async {
      _seedAvatar('user-abc');
      _seedAvatar('local-user');

      await service.remove('local-user');

      expect(service.currentAvatar('local-user'), isNull);
      expect(service.currentAvatar('user-abc'), isNotNull);
    });

    test('a missing file reads as no avatar', () {
      final file = _seedAvatar('user-abc');
      file.deleteSync();

      expect(service.currentAvatar('user-abc'), isNull);
    });

    test('the legacy device-wide avatar is discarded, not inherited', () {
      final legacy = File('${tempDir.path}/legacy.jpg')
        ..writeAsBytesSync([9, 9, 9]);
      AppDatabase.box(StorageBoxes.settings).put('avatar_path', legacy.path);

      // Whoever reads first must not inherit it.
      expect(service.currentAvatar('local-user'), isNull);
      expect(
        AppDatabase.box(StorageBoxes.settings).containsKey('avatar_path'),
        isFalse,
      );
      expect(legacy.existsSync(), isFalse);
    });

    test('ids with filesystem-hostile characters are handled', () async {
      // Sanity-check the sanitiser used for filenames via the public API.
      const messyId = 'user/with:bad*chars';
      final box = AppDatabase.box(StorageBoxes.settings);
      final file = File('${tempDir.path}/ok.jpg')..writeAsBytesSync([1]);
      await box.put('avatar_path_$messyId', file.path);

      expect(service.currentAvatar(messyId), isNotNull);
    });
  });
}
