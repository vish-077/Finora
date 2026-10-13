import 'dart:convert';

import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/sync/pending_op.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_tables.dart';

/// Identifiers for who the local boxes currently belong to.
class SyncScope {
  SyncScope._();

  /// Guest mode. Deliberately not a UUID, so it can never collide with a
  /// Firebase `uid` and can never be pushed as a `user_id`.
  static const String guest = 'local-user';

  static bool isGuest(String? owner) => owner == null || owner == guest;
}

/// Makes the mirrored SQLite boxes belong to exactly one owner at a time.
///
/// The boxes are opened once at startup and injected all over the app, so
/// swapping box *instances* per account isn't practical here. Instead this
/// store swaps the *contents*: on an owner change the outgoing owner's rows
/// and outbox are stashed under their id, the live boxes are emptied, and the
/// incoming owner's stash (if any) is restored.
///
/// That gives three things at once:
///   * guest never sees an authenticated user's rows, and vice versa;
///   * a guest's own entries survive across guest sessions;
///   * a signed-out user's *unsent* writes are preserved rather than deleted,
///     and go up the next time that account signs in on this device.
class SyncScopeStore {
  SyncScopeStore({
    required SqlBox box,
    required SyncLocalStore store,
    required SyncQueue queue,
  })  : _box = box,
        _store = store,
        _queue = queue;

  final SqlBox _box;
  final SyncLocalStore _store;
  final SyncQueue _queue;

  static const String _activeKey = 'scope.active';
  static String _stashKey(String owner) => 'scope.stash.$owner';

  /// Who the live boxes currently belong to, or null on a device that has
  /// never been claimed.
  String? get activeOwner {
    final raw = _box.get(_activeKey);
    return raw is String ? raw : null;
  }

  bool get isGuestActive => SyncScope.isGuest(activeOwner);

  /// Claims whatever is already in the boxes for [owner] *without* clearing.
  ///
  /// Used once, when upgrading a device that pre-dates scoping: its boxes hold
  /// real data that belongs to the last account that synced here.
  Future<void> adopt(String owner) async {
    if (activeOwner != null) return;
    LogService.i('SyncScope: adopting existing local data for "$owner"');
    await _box.put(_activeKey, owner);
  }

  /// Makes [owner] the active owner. Returns true if a swap actually happened.
  ///
  /// Serialized: sign-in can be requested twice at once (Firebase replays the
  /// current user on subscribe just as startup calls `handleSignIn`), and two
  /// interleaved swaps would stash a half-cleared box.
  Future<bool> switchTo(String owner, {bool force = false}) {
    final next = _lock.then((_) => _switchTo(owner, force: force));
    _lock = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _lock = Future<void>.value();

  Future<bool> _switchTo(String owner, {bool force = false}) async {
    final current = activeOwner;
    if (current == owner && !force) return false;

    if (current != null) await _stash(current);
    await _store.clearAll();
    await _queue.clear();
    await _restore(owner);
    await _box.put(_activeKey, owner);

    LogService.i('SyncScope: switched local data from "$current" to "$owner" (force=$force)');
    return true;
  }

  /// Drops [owner]'s stash. Their cloud rows are untouched — this only frees
  /// the local copy.
  Future<void> forget(String owner) => _box.delete(_stashKey(owner));

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<void> _stash(String owner) async {
    final tables = <String, Map<String, dynamic>>{};
    var rowCount = 0;
    for (final table in SyncTables.all) {
      final rows = _store.readAll(table);
      if (rows.isEmpty) continue;
      tables[table.remote] = <String, dynamic>{
        for (final row in rows)
          if (row['id'] is String) row['id'] as String: row,
      };
      rowCount += rows.length;
    }

    final ops = _queue.all();
    if (tables.isEmpty && ops.isEmpty) {
      await _box.delete(_stashKey(owner));
      return;
    }

    await _box.put(
      _stashKey(owner),
      jsonEncode(<String, dynamic>{
        'tables': tables,
        'queue': [for (final op in ops) op.toMap()],
      }),
    );
    LogService.d(
      'SyncScope: stashed $rowCount row(s) and ${ops.length} pending op(s) '
      'for "$owner"',
    );
  }

  Future<void> _restore(String owner) async {
    final raw = _box.get(_stashKey(owner));
    if (raw is! String) return;

    Map<String, dynamic> snapshot;
    try {
      snapshot = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      LogService.w('SyncScope: unreadable stash for "$owner" — dropping ($e)');
      await _box.delete(_stashKey(owner));
      return;
    }

    final tables = snapshot['tables'];
    if (tables is Map) {
      for (final entry in tables.entries) {
        final table = SyncTables.byRemote('${entry.key}');
        final rows = entry.value;
        if (table == null || rows is! Map) continue;
        for (final row in rows.values) {
          if (row is Map) {
            await _store.put(table, Map<String, dynamic>.from(row));
          }
        }
      }
    }

    final ops = snapshot['queue'];
    if (ops is List) {
      for (final op in ops) {
        if (op is! Map) continue;
        try {
          await _queue.restore(
            PendingOp.fromMap(Map<String, dynamic>.from(op)),
          );
        } catch (_) {
          // A single malformed op must not block the whole restore.
        }
      }
    }

    await _box.delete(_stashKey(owner));
    LogService.d('SyncScope: restored local data for "$owner"');
  }
}
