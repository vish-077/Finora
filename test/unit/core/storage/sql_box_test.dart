import 'dart:io';

import 'package:finora/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real SQLite engine (via the FFI build) — closing and
/// reopening the database must bring every value back with its type intact.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finora_sqlite_test');
    dbPath = '${tempDir.path}/finora.db';
    await AppDatabase.init(path: dbPath);
  });

  tearDown(() async {
    await AppDatabase.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> reopen() async {
    await AppDatabase.close();
    await AppDatabase.init(path: dbPath);
  }

  test('values survive closing and reopening the database', () async {
    final box = await AppDatabase.openBox('things');
    await box.put('string', 'hello');
    await box.put('int', 42);
    await box.put('double', 1.5);
    await box.put('bool', true);
    await box.put('list', <dynamic>[1, 'two']);
    await box.put('map', <String, dynamic>{'a': 1, 'b': <String, dynamic>{'c': 2}});

    await reopen();
    final again = await AppDatabase.openBox('things');

    expect(again.get('string'), 'hello');
    expect(again.get('int'), 42);
    expect(again.get('double'), 1.5);
    expect(again.get('bool'), true);
    expect(again.get('list'), <dynamic>[1, 'two']);
    expect(again.get('map'), <String, dynamic>{'a': 1, 'b': <String, dynamic>{'c': 2}});
    expect(again.length, 6);
  });

  test('put replaces, delete and clear remove — and persist', () async {
    final box = await AppDatabase.openBox('things');
    await box.put('k', 'v1');
    await box.put('k', 'v2');
    await box.put('gone', 'x');
    await box.delete('gone');
    await box.put('a', 1);
    await box.put('b', 2);
    await box.deleteAll(['a']);

    await reopen();
    final again = await AppDatabase.openBox('things');
    expect(again.get('k'), 'v2');
    expect(again.containsKey('gone'), isFalse);
    expect(again.containsKey('a'), isFalse);
    expect(again.get('b'), 2);

    await again.clear();
    await reopen();
    expect((await AppDatabase.openBox('things')).isEmpty, isTrue);
  });

  test('boxes are isolated from one another', () async {
    final one = await AppDatabase.openBox('one');
    final two = await AppDatabase.openBox('two');
    await one.put('k', 'from-one');
    await two.put('k', 'from-two');
    await one.clear();

    await reopen();
    expect((await AppDatabase.openBox('one')).isEmpty, isTrue);
    expect((await AppDatabase.openBox('two')).get('k'), 'from-two');
  });

  test('watch emits after writes and deletes', () async {
    final box = await AppDatabase.openBox('things');
    final events = <String?>[];
    final sub = box.watch().listen((e) => events.add(e.deleted ? '-${e.key}' : '+${e.key}'));

    await box.put('x', 1);
    await box.delete('x');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, ['+x', '-x']);
  });

  test('opening a box before init fails loudly', () async {
    await AppDatabase.close();
    expect(() => AppDatabase.openBox('nope'), throwsStateError);
  });
}
