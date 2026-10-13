import 'dart:convert';

import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/core/sync/sync_tables.dart';

/// Raw JSON access to the mirrored SQLite boxes.
///
/// Feature code keeps using its typed local sources for reads; the sync engine
/// works at the map level so one implementation covers every table.
class SyncLocalStore {
  SqlBox box(SyncTable table) => AppDatabase.box(table.box);

  Map<String, dynamic>? read(SyncTable table, String id) =>
      _decode(box(table).get(id));

  List<Map<String, dynamic>> readAll(SyncTable table) {
    final rows = <Map<String, dynamic>>[];
    for (final value in box(table).values) {
      final row = _decode(value);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  Future<void> put(SyncTable table, Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null || id.isEmpty) return;
    await box(table).put(id, jsonEncode(row));
  }

  Future<void> delete(SyncTable table, String id) => box(table).delete(id);

  /// Wipes every mirrored box. Used when the signed-in account changes so one
  /// user never sees another's cached rows.
  Future<void> clearAll() async {
    for (final table in SyncTables.all) {
      await box(table).clear();
    }
  }

  Map<String, dynamic>? _decode(Object? value) {
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
