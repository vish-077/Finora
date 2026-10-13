import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/storage/sql_box.dart';

/// Owns the app's single SQLite database and hands out [SqlBox] collections.
///
/// ```dart
/// await AppDatabase.init();
/// await AppDatabase.openBoxes(StorageBoxes.all);
/// final settings = AppDatabase.box(StorageBoxes.settings);
/// ```
class AppDatabase {
  AppDatabase._();

  static const String fileName = 'finora.db';
  static const int _version = 1;

  static Database? _db;
  static bool _inMemory = false;
  static final Map<String, SqlBox> _boxes = <String, SqlBox>{};

  /// Opens (creating if needed) the on-device database.
  ///
  /// [path] overrides the default `<databases dir>/finora.db`.
  static Future<void> init({String? path}) async {
    await close();
    final dbPath = path ?? p.join(await getDatabasesPath(), fileName);
    _db = await openDatabase(
      dbPath,
      version: _version,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE ${SqlBox.table} ('
          'box TEXT NOT NULL, '
          'key TEXT NOT NULL, '
          'value TEXT NOT NULL, '
          'PRIMARY KEY (box, key))',
        );
      },
    );
    LogService.d('SQLite database opened at $dbPath');
  }

  /// Boxes with no database behind them — for unit and widget tests. Resets
  /// every open box, so each test starts from empty storage.
  static void initInMemory() {
    _boxes.clear();
    _db = null;
    _inMemory = true;
  }

  static Future<SqlBox> openBox(String name) async {
    final existing = _boxes[name];
    if (existing != null) return existing;

    final db = _db;
    final SqlBox box;
    if (db != null) {
      box = SqlBox.internal(name, db, await SqlBox.load(db, name));
    } else if (_inMemory) {
      box = SqlBox.memory(name);
    } else {
      throw StateError('AppDatabase.init() must run before opening "$name"');
    }
    _boxes[name] = box;
    return box;
  }

  static Future<void> openBoxes(Iterable<String> names) async {
    for (final name in names) {
      await openBox(name);
    }
  }

  /// The open box called [name]. Throws [StateError] when it isn't open.
  static SqlBox box(String name) {
    final box = _boxes[name];
    if (box == null) {
      throw StateError('Box "$name" is not open');
    }
    return box;
  }

  static bool isBoxOpen(String name) => _boxes.containsKey(name);

  /// Closes the database and forgets every open box (data stays on disk).
  static Future<void> close() async {
    _boxes.clear();
    _inMemory = false;
    final db = _db;
    _db = null;
    await db?.close();
  }

  /// Deletes every stored row of the open boxes. Used by tests for isolation.
  static Future<void> deleteFromDisk() async {
    for (final box in _boxes.values.toList()) {
      await box.clear();
    }
  }
}
