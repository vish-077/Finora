import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/sync/stable_id.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_tables.dart';

/// One-time repair of data written before multi-device sync existed.
///
/// Seeded rows used ids like `default-food`. the original schema declared those columns
/// `uuid`, so every write that touched one was rejected by the server and the
/// row — plus every expense referencing it — stayed on the device that made
/// it. This rewrites those ids to their deterministic UUID form, repoints the
/// referencing rows, and queues everything already on the device for upload so
/// existing data is adopted into the account instead of abandoned.
class LegacyIdMigration {
  LegacyIdMigration({
    required SqlBox settingsBox,
    required SyncLocalStore store,
    required SyncQueue queue,
  })  : _settings = settingsBox,
        _store = store,
        _queue = queue;

  static const String _flag = 'sync.legacy_ids_migrated_v1';

  final SqlBox _settings;
  final SyncLocalStore _store;
  final SyncQueue _queue;

  bool get isDone => _settings.get(_flag) == true;

  Future<void> run() async {
    if (isDone) return;

    final remapped = <String, String>{};
    await _remapIds(SyncTables.categories, remapped, _categorySeed);
    await _remapIds(SyncTables.accounts, remapped, _accountSeed);
    await _repointReferences(SyncTables.expenses, remapped,
        const ['category_id', 'account_id']);
    await _repointReferences(SyncTables.budgets, remapped, const ['category_id']);
    await _adoptLocalRows();

    await _settings.put(_flag, true);
    LogService.i(
      'LegacyIdMigration: rewrote ${remapped.length} ids, '
      'queued ${_queue.length} rows for upload',
    );
  }

  String _categorySeed(Map<String, dynamic> row) =>
      'category:${row['user_id']}:'
      '${(row['name'] as String? ?? '').toLowerCase()}';

  String _accountSeed(Map<String, dynamic> row) =>
      row['id'] == 'default-cash'
          ? 'account:${row['user_id']}:cash'
          : 'account:${row['user_id']}:${row['id']}';

  Future<void> _remapIds(
    SyncTable table,
    Map<String, String> remapped,
    String Function(Map<String, dynamic>) seed,
  ) async {
    for (final row in _store.readAll(table)) {
      final oldId = row['id'] as String?;
      if (oldId == null || isUuid(oldId)) continue;

      final newId = stableId(seed(row));
      remapped[oldId] = newId;
      await _store.delete(table, oldId);
      await _store.put(table, {...row, 'id': newId});
    }
  }

  Future<void> _repointReferences(
    SyncTable table,
    Map<String, String> remapped,
    List<String> columns,
  ) async {
    if (remapped.isEmpty) return;

    for (final row in _store.readAll(table)) {
      final id = row['id'] as String?;
      if (id == null) continue;

      var changed = false;
      final updated = Map<String, dynamic>.from(row);
      for (final column in columns) {
        final value = updated[column];
        if (value is String && remapped.containsKey(value)) {
          updated[column] = remapped[value];
          changed = true;
        }
      }
      if (changed) await _store.put(table, updated);
    }
  }

  /// Queues every locally-held row. The push path pins `user_id` to the
  /// signed-in account, so rows saved before sign-in are claimed correctly.
  Future<void> _adoptLocalRows() async {
    var skipped = 0;
    for (final table in SyncTables.all) {
      for (final row in _store.readAll(table)) {
        final id = row['id'] as String?;
        if (id == null || !isUuid(id)) {
          // A non-uuid key is not synced; leave the row on
          // the device rather than wedging the queue with it.
          skipped++;
          continue;
        }
        await _queue.enqueueUpsert(table, row);
      }
    }
    if (skipped > 0) {
      LogService.w(
        'LegacyIdMigration: $skipped row(s) kept device-local — id is not a UUID',
      );
    }
  }
}
