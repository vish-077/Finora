import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/core/sync/sync_tables.dart';

/// Per-user, per-table high-water mark: the newest `updated_at` this device
/// has already pulled. The next pull asks only for rows newer than this, so a
/// resumed device fetches a delta rather than the whole account.
class SyncCursorStore {
  SyncCursorStore(this._box);

  final SqlBox _box;

  static const String _lastUserKey = 'sync.last_user_id';
  static const String _lastSyncedKey = 'sync.last_synced_at';

  String _key(String userId, SyncTable table) =>
      'sync.cursor.$userId.${table.remote}';

  DateTime? cursor(String userId, SyncTable table) {
    final raw = _box.get(_key(userId, table));
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> setCursor(String userId, SyncTable table, DateTime value) =>
      _box.put(_key(userId, table), value.toUtc().toIso8601String());

  bool hasEverSynced(String userId) =>
      SyncTables.all.any((t) => cursor(userId, t) != null);

  /// The account whose data currently lives in the local boxes.
  String? get lastUserId {
    final raw = _box.get(_lastUserKey);
    return raw is String ? raw : null;
  }

  Future<void> setLastUserId(String userId) => _box.put(_lastUserKey, userId);

  DateTime? get lastSyncedAt {
    final raw = _box.get(_lastSyncedKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> setLastSyncedAt(DateTime value) =>
      _box.put(_lastSyncedKey, value.toUtc().toIso8601String());

  /// Forgets every cursor for [userId] — the next sync becomes a full pull.
  Future<void> resetCursors(String userId) async {
    for (final table in SyncTables.all) {
      await _box.delete(_key(userId, table));
    }
    await _box.delete(_lastSyncedKey);
  }

  Future<void> resetAll() async {
    final keys = _box.keys
        .whereType<String>()
        .where((k) => k.startsWith('sync.'))
        .toList();
    await _box.deleteAll(keys);
  }
}
