import 'package:finora/core/sync/sync_engine.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_tables.dart';

/// The single write path for synced data.
///
/// Repositories call this instead of talking to Firestore directly: the local
/// box is updated immediately (so the UI stays instant and offline-capable),
/// the mutation is queued durably, and a sync round is nudged. Nothing depends
/// on the network call succeeding right now.
class SyncWriter {
  SyncWriter({
    required SyncQueue queue,
    required SyncLocalStore store,
    required SyncEngine engine,
  })  : _queue = queue,
        _store = store,
        _engine = engine;

  final SyncQueue _queue;
  final SyncLocalStore _store;
  final SyncEngine _engine;

  /// Writes [row] locally and queues it for the server.
  /// Returns the row as stored, with its `updated_at` stamp applied.
  Future<Map<String, dynamic>> save(
    SyncTable table,
    Map<String, dynamic> row,
  ) async {
    final stamped = Map<String, dynamic>.from(row)
      ..['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _store.put(table, stamped);
    // Guest writes are local-only: there is no account to own them, and
    // queueing them would upload guest data under whichever user signs in
    // next. A signed-in user who is merely offline still queues normally.
    if (_engine.canQueueUploads) {
      await _queue.enqueueUpsert(table, stamped);
      _engine.requestSync(reason: 'write:${table.remote}');
    }
    return stamped;
  }

  /// Removes [id] locally and queues a tombstone so other devices drop it too.
  Future<void> remove(SyncTable table, String id) async {
    await _store.delete(table, id);
    if (_engine.canQueueUploads) {
      await _queue.enqueueDelete(table, id);
      _engine.requestSync(reason: 'delete:${table.remote}');
    }
  }

  /// Called before a read. Blocks only on a device that has never pulled this
  /// account; otherwise it refreshes in the background.
  Future<void> prepareRead() => _engine.ensureInitialSync();
}
