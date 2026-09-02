import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/network/network_info.dart';
import 'package:finora/core/sync/pending_op.dart';
import 'package:finora/core/sync/sync_cursor_store.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_scope.dart';
import 'package:finora/core/sync/sync_status.dart';
import 'package:finora/core/sync/sync_tables.dart';

/// Keeps every device signed into the same account on the same data.
///
/// Each round is push-then-pull:
///   * **push** drains the outbox, so nothing written on this device is
///     stranded here;
///   * **pull** fetches rows changed since this device's cursor and merges
///     them into the local boxes, so work done on another device shows up.
///
/// Rounds are triggered by sign-in, app resume, reconnect, a realtime event
/// from another device, a local write, and a slow periodic tick.
class SyncEngine {
  SyncEngine({
    required SupabaseClient? client,
    required SyncQueue queue,
    required SyncLocalStore store,
    required SyncCursorStore cursors,
    required SyncScopeStore scopes,
    required NetworkInfo network,
  })  : _client = client,
        _queue = queue,
        _store = store,
        _cursors = cursors,
        _scopes = scopes,
        _network = network;

  final SupabaseClient? _client;
  final SyncQueue _queue;
  final SyncLocalStore _store;
  final SyncCursorStore _cursors;
  final SyncScopeStore _scopes;
  final NetworkInfo _network;

  static const Duration _debounce = Duration(milliseconds: 500);
  static const Duration _period = Duration(minutes: 2);
  static const int _pageSize = 500;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _status = const SyncStatus();
  bool _running = false;
  bool _rerunRequested = false;
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  RealtimeChannel? _channel;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<AuthState>? _authSub;
  Completer<void>? _initialSync;

  SyncStatus get status => _status;
  Stream<SyncStatus> get statusStream => _statusController.stream;

  String? get _uid => _client?.auth.currentUser?.id;
  bool get _isCloudReady => _client != null && _uid != null;

  /// True while the local boxes belong to guest mode rather than a signed-in
  /// account. Guest writes stay on the device: they must never be uploaded
  /// under the previous user's id.
  bool get isGuestScope => _uid == null || _scopes.isGuestActive;

  /// Whether a local write may be added to the outbox. False in guest mode;
  /// still true for a signed-in user who happens to be offline.
  bool get canQueueUploads => !isGuestScope;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> start() async {
    // A device upgrading from a pre-scoping build has unclaimed boxes. Claim
    // them for the account that last synced here (or guest, if none did)
    // before any switch can clear them.
    if (_scopes.activeOwner == null) {
      await _scopes.adopt(_cursors.lastUserId ?? SyncScope.guest);
    }

    if (_client == null) {
      LogService.w('SyncEngine: Supabase not configured — running local-only');
      _emit(const SyncStatus(state: SyncState.signedOut));
      return;
    }

    _authSub = _client.auth.onAuthStateChange.listen((event) async {
      final userId = event.session?.user.id;
      if (userId == null) {
        await enterGuestMode();
      } else {
        await handleSignIn(userId);
      }
    });

    _connectivitySub = _network.onConnectivityChanged.listen((online) {
      if (online) requestSync(reason: 'reconnected');
    });

    _periodicTimer = Timer.periodic(_period, (_) => requestSync(reason: 'tick'));

    final userId = _uid;
    if (userId != null) {
      await handleSignIn(userId);
    } else {
      // No Supabase session: whatever is in the boxes must not be shown to
      // whoever uses the app next. Park them under their owner and hand the
      // device to guest. Also covers a crash midway through sign-out.
      await enterGuestMode();
    }
  }

  /// Hands the local boxes to guest mode.
  ///
  /// The outgoing owner's rows and unsent writes are stashed, not deleted, so
  /// signing back in on this device restores them; guest starts from its own
  /// (initially empty) data and stays there.
  Future<void> enterGuestMode() async {
    await _unsubscribeRealtime();
    _initialSync = null;
    await _scopes.switchTo(SyncScope.guest, force: true);
    _emit(const SyncStatus(state: SyncState.signedOut));
  }

  /// Prepares local storage for [userId] and kicks off the first round.
  ///
  /// Anything the boxes hold for a different owner (another account, or guest)
  /// is stashed under that owner and replaced by this user's own local data —
  /// so no rows ever bleed across logins, and nothing is destroyed either.
  Future<void> handleSignIn(String userId) async {
    await _scopes.switchTo(userId);
    await _cursors.setLastUserId(userId);
    _subscribeRealtime(userId);
    requestSync(reason: 'signed-in');
  }

  /// Hands this device's copy of the account back to guest mode.
  ///
  /// Call this *before* revoking the Supabase session: it flushes anything
  /// still queued while the token is valid. Changes that can't be flushed stay
  /// in the outbox and go up the next time this account signs in here.
  Future<void> handleSignOut() async {
    if (_isCloudReady && _queue.length > 0 && await _network.isConnected) {
      try {
        await syncNow(reason: 'sign-out');
      } catch (e) {
        LogService.w('SyncEngine: final flush before sign-out failed — $e');
      }
    }

    final unflushed = _queue.length;
    if (unflushed > 0) {
      // Those rows exist ONLY on this device. They are stashed under this
      // account by the scope switch below — not deleted, and not left visible
      // to whoever uses the app next. The next sign-in to this account
      // restores them and uploads them.
      LogService.w(
        'SyncEngine: signing out with $unflushed unsent change(s) — stashing '
        'them for this account; they will upload on the next sign-in here',
      );
    }

    // Hands the device to guest with an empty (or guest-owned) data set.
    await enterGuestMode();
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    await _unsubscribeRealtime();
    await _connectivitySub?.cancel();
    await _authSub?.cancel();
    await _statusController.close();
  }

  // ── Triggers ───────────────────────────────────────────────────────────────

  /// Coalesced, fire-and-forget sync. Safe to call on every local write.
  void requestSync({String reason = 'requested'}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(syncNow(reason: reason));
    });
  }

  void onAppResumed() => requestSync(reason: 'resumed');

  /// Awaited by the first read after launch on a device that has never synced
  /// this account, so a fresh install shows the account's data instead of an
  /// empty screen.
  Future<void> ensureInitialSync() async {
    final userId = _uid;
    if (userId == null) return;
    if (_cursors.hasEverSynced(userId)) {
      requestSync(reason: 'read');
      return;
    }
    // Concurrent first reads share one round…
    final existing = _initialSync;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _initialSync = completer;
    try {
      await syncNow(reason: 'initial');
    } finally {
      // …but a round that failed (offline, server error) must not latch: the
      // next read should try again rather than settle for an empty screen.
      _initialSync = null;
      if (!completer.isCompleted) completer.complete();
    }
    return completer.future;
  }

  // ── The round ──────────────────────────────────────────────────────────────

  Future<void> syncNow({String reason = 'manual'}) async {
    if (!_isCloudReady) {
      _emit(_status.copyWith(state: SyncState.signedOut));
      return;
    }
    if (_running) {
      // Fold concurrent requests into one follow-up round.
      _rerunRequested = true;
      return;
    }
    if (!await _network.isConnected) {
      _emit(_status.copyWith(
        state: SyncState.offline,
        pending: _queue.length,
      ));
      return;
    }

    _running = true;
    _emit(_status.copyWith(
      state: SyncState.syncing,
      pending: _queue.length,
      clearMessage: true,
    ));

    var failed = false;
    String? message;
    try {
      LogService.d('SyncEngine: round start ($reason)');
      await _push();
      await _pull();
      await _cursors.setLastSyncedAt(DateTime.now().toUtc());
    } catch (e, stack) {
      failed = true;
      message = e.toString();
      LogService.e('SyncEngine: round failed', error: e, stackTrace: stack);
    } finally {
      _running = false;
    }

    _emit(SyncStatus(
      state: failed ? SyncState.error : SyncState.synced,
      pending: _queue.length,
      lastSyncedAt: _cursors.lastSyncedAt ?? _status.lastSyncedAt,
      message: message,
    ));

    if (_rerunRequested) {
      _rerunRequested = false;
      requestSync(reason: 'coalesced');
    }
  }

  Future<void> _push() async {
    final userId = _uid;
    if (userId == null) return;

    for (final op in _queue.ready(DateTime.now().toUtc())) {
      final table = SyncTables.byRemote(op.table);
      if (table == null) {
        await _queue.complete(op);
        continue;
      }
      try {
        switch (op.type) {
          case SyncOpType.upsert:
            final payload = _sanitize(op.payload, userId);
            if (payload == null) {
              await _queue.complete(op);
              continue;
            }
            final row = await _client!
                .from(table.remote)
                .upsert(payload)
                .select()
                .maybeSingle();
            if (row != null) {
              // Adopt the server's timestamps so the next pull doesn't
              // consider this row stale.
              await _store.put(table, Map<String, dynamic>.from(row));
            }
          case SyncOpType.delete:
            await _client!
                .from(table.remote)
                .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
                .eq('id', op.rowId)
                .eq('user_id', userId);
            await _store.delete(table, op.rowId);
        }
        await _queue.complete(op);
      } on PostgrestException catch (e) {
        LogService.w(
          'SyncEngine: push failed for ${op.key} — ${e.code}: ${e.message}',
        );
        await _queue.fail(op, e);
      } catch (e) {
        LogService.w('SyncEngine: push failed for ${op.key} — $e');
        await _queue.fail(op, e);
      }
    }
  }

  Future<void> _pull() async {
    final userId = _uid;
    if (userId == null) return;

    for (final table in SyncTables.all) {
      // Rows this device still owes the server must not be clobbered by an
      // older server copy.
      final protected = _queue.pendingRowIds(table);
      var cursor = _cursors.cursor(userId, table);

      while (true) {
        var query =
            _client!.from(table.remote).select().eq('user_id', userId);
        if (cursor != null) {
          query = query.gt('updated_at', cursor.toUtc().toIso8601String());
        }
        final rows = await query
            .order('updated_at', ascending: true)
            .limit(_pageSize);

        if (rows.isEmpty) break;

        DateTime? newest;
        for (final raw in rows) {
          final row = Map<String, dynamic>.from(raw);
          final id = row['id'] as String?;
          if (id == null) continue;

          final updatedAt = DateTime.tryParse('${row['updated_at']}');
          if (updatedAt != null &&
              (newest == null || updatedAt.isAfter(newest))) {
            newest = updatedAt;
          }

          if (protected.contains(id)) continue;

          if (row['deleted_at'] != null) {
            await _store.delete(table, id);
          } else {
            await _store.put(table, row);
          }
        }

        if (newest != null) {
          cursor = newest;
          await _cursors.setCursor(userId, table, newest);
        }
        if (rows.length < _pageSize) break;
      }
    }
  }

  /// Strips keys Postgres must fill in itself and pins ownership to the
  /// signed-in user so a queued row can never be pushed under the wrong id.
  Map<String, dynamic>? _sanitize(Map<String, dynamic>? payload, String userId) {
    if (payload == null) return null;
    final row = Map<String, dynamic>.from(payload)
      ..removeWhere((key, value) =>
          value == null &&
          (key == 'created_at' || key == 'updated_at' || key == 'deleted_at'));
    row['user_id'] = userId;
    return row;
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  void _subscribeRealtime(String userId) {
    final client = _client;
    if (client == null) return;
    unawaited(_unsubscribeRealtime());

    final channel = client.channel('finora_sync_$userId');
    for (final table in SyncTables.all) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table.remote,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => requestSync(reason: 'realtime:${table.remote}'),
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _unsubscribeRealtime() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client?.removeChannel(channel);
    }
  }

  void _emit(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }
}
