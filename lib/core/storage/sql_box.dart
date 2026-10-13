import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// A named key/value collection stored in the app's SQLite database.
///
/// Every feature reads and writes its data through one of
/// these. Rows live in the shared `kv_store` table (`box`, `key`, `value`); the
/// whole collection is also held in memory, so reads stay synchronous and
/// instant while every write is persisted to SQLite before its future
/// completes.
///
/// Values may be any JSON-encodable object (String, num, bool, List, Map or
/// null) and come back with the same type they went in with.
class SqlBox {
  SqlBox.internal(this.name, this._db, Map<String, dynamic> initial)
      : _entries = Map<String, dynamic>.of(initial);

  /// A box with no database behind it. Used by tests, and by early-boot
  /// fallbacks that must not crash when storage is unavailable.
  SqlBox.memory(this.name)
      : _db = null,
        _entries = <String, dynamic>{};

  static const String table = 'kv_store';

  final String name;
  final Database? _db;
  final Map<String, dynamic> _entries;
  final StreamController<BoxEvent> _events =
      StreamController<BoxEvent>.broadcast();

  // ── Reads (synchronous, served from memory) ──────────────────────────────

  dynamic get(String key, {dynamic defaultValue}) =>
      _entries.containsKey(key) ? _entries[key] : defaultValue;

  bool containsKey(String key) => _entries.containsKey(key);

  Iterable<String> get keys => _entries.keys;
  Iterable<dynamic> get values => _entries.values;
  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  // ── Change stream ────────────────────────────────────────────────────────

  /// Emits after every successful write, for UI that reacts to storage.
  Stream<BoxEvent> watch() => _events.stream;

  void _notify(BoxEvent event) {
    if (!_events.isClosed && _events.hasListener) _events.add(event);
  }

  // ── Writes (memory first, then SQLite) ───────────────────────────────────

  Future<void> put(String key, dynamic value) async {
    // Re-insert so the entry moves to the end, matching SQLite's rowid order
    // after `INSERT OR REPLACE`.
    _entries.remove(key);
    _entries[key] = value;
    await _db?.insert(
      table,
      <String, Object?>{'box': name, 'key': key, 'value': jsonEncode(value)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify(BoxEvent(key: key, value: value));
  }

  Future<void> putAll(Map<String, dynamic> entries) async {
    if (entries.isEmpty) return;
    for (final entry in entries.entries) {
      _entries.remove(entry.key);
      _entries[entry.key] = entry.value;
    }
    final db = _db;
    if (db != null) {
      final batch = db.batch();
      for (final entry in entries.entries) {
        batch.insert(
          table,
          <String, Object?>{
            'box': name,
            'key': entry.key,
            'value': jsonEncode(entry.value),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }
    for (final entry in entries.entries) {
      _notify(BoxEvent(key: entry.key, value: entry.value));
    }
  }

  Future<void> delete(String key) async {
    _entries.remove(key);
    await _db?.delete(table, where: 'box = ? AND key = ?', whereArgs: [name, key]);
    _notify(BoxEvent(key: key, deleted: true));
  }

  Future<void> deleteAll(Iterable<String> keys) async {
    final list = keys.toList();
    if (list.isEmpty) return;
    list.forEach(_entries.remove);
    final db = _db;
    if (db != null) {
      final batch = db.batch();
      for (final key in list) {
        batch.delete(table, where: 'box = ? AND key = ?', whereArgs: [name, key]);
      }
      await batch.commit(noResult: true);
    }
    for (final key in list) {
      _notify(BoxEvent(key: key, deleted: true));
    }
  }

  Future<void> clear() async {
    final hadEntries = _entries.isNotEmpty;
    _entries.clear();
    await _db?.delete(table, where: 'box = ?', whereArgs: [name]);
    if (hadEntries) _notify(const BoxEvent(key: null, deleted: true));
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Reads every persisted row of box [name] into a map, in insertion order.
  static Future<Map<String, dynamic>> load(Database db, String name) async {
    final rows = await db.query(
      table,
      columns: ['key', 'value'],
      where: 'box = ?',
      whereArgs: [name],
      orderBy: 'rowid ASC',
    );
    final entries = <String, dynamic>{};
    for (final row in rows) {
      try {
        entries[row['key']! as String] = jsonDecode(row['value']! as String);
      } on FormatException {
        // A corrupt row is skipped rather than failing the whole box.
      }
    }
    return entries;
  }
}

/// A change to a [SqlBox]: [key] was written ([value]) or removed
/// ([deleted]). A null key means the whole box was cleared.
class BoxEvent {
  const BoxEvent({required this.key, this.value, this.deleted = false});

  final String? key;
  final dynamic value;
  final bool deleted;
}
