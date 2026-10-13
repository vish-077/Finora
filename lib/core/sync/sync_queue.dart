import 'dart:convert';
import 'dart:math' as math;

import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/core/config/app_config.dart';
import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/sync/pending_op.dart';
import 'package:finora/core/sync/sync_tables.dart';

/// Durable outbox. Every local write lands here first, so a mutation made
/// offline (or during a failed request) still reaches the server later
/// instead of being silently stranded on one device.
class SyncQueue {
  SyncQueue(this._box);

  final SqlBox _box;

  Future<void> enqueueUpsert(SyncTable table, Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null || id.isEmpty) {
      LogService.w('SyncQueue: refusing to queue a row without an id '
          '(${table.remote})');
      return;
    }
    await _put(
      PendingOp(
        table: table.remote,
        rowId: id,
        type: SyncOpType.upsert,
        payload: row,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> enqueueDelete(SyncTable table, String rowId) async {
    // A delete supersedes any queued edit for the same row.
    await _put(
      PendingOp(
        table: table.remote,
        rowId: rowId,
        type: SyncOpType.delete,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  List<PendingOp> all() {
    final ops = <PendingOp>[];
    for (final value in _box.values) {
      final op = _decode(value);
      if (op != null) ops.add(op);
    }
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  /// Ops whose backoff window has elapsed, in FK-safe table order.
  List<PendingOp> ready(DateTime now) {
    final ops = all().where((op) => op.isReady(now)).toList();
    int rank(String table) {
      final index =
          SyncTables.all.indexWhere((t) => t.remote == table);
      return index < 0 ? SyncTables.all.length : index;
    }

    ops.sort((a, b) {
      final byTable = rank(a.table).compareTo(rank(b.table));
      return byTable != 0 ? byTable : a.createdAt.compareTo(b.createdAt);
    });
    return ops;
  }

  int get length => _box.length;

  /// Row ids with unsent changes for [table]. A pull must not overwrite these
  /// — the local copy is newer than anything the server can hand back.
  Set<String> pendingRowIds(SyncTable table) => all()
      .where((op) => op.table == table.remote)
      .map((op) => op.rowId)
      .toSet();

  Future<void> complete(PendingOp op) => _box.delete(op.key);

  /// Exponential backoff, capped. Ops older than the cap are dropped so a
  /// permanently poisoned row can't wedge the queue forever.
  Future<void> fail(PendingOp op, Object error) async {
    final retries = op.retries + 1;
    final delaySeconds = math.min(
      AppConfig.syncRetryBaseSeconds * math.pow(2, retries - 1).toInt(),
      AppConfig.syncMaxRetryHours * 3600,
    );
    final age = DateTime.now().toUtc().difference(op.createdAt);
    if (age.inHours >= AppConfig.syncMaxRetryHours) {
      LogService.e(
        'SyncQueue: dropping ${op.key} after ${age.inHours}h of failures',
        error: error,
      );
      await _box.delete(op.key);
      return;
    }
    await _put(
      op.copyWith(
        retries: retries,
        nextAttemptAt:
            DateTime.now().toUtc().add(Duration(seconds: delaySeconds)),
        lastError: error.toString(),
      ),
    );
  }

  Future<void> clear() => _box.clear();

  /// Puts a previously stashed op back, retry state and all. Used when an
  /// account's local scope is restored after signing back in on this device.
  Future<void> restore(PendingOp op) => _put(op);

  Future<void> _put(PendingOp op) => _box.put(op.key, jsonEncode(op.toMap()));

  PendingOp? _decode(Object? value) {
    if (value is! String) return null;
    try {
      return PendingOp.fromMap(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
