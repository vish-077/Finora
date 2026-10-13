enum SyncState {
  /// No signed-in Firebase user — the app is running purely local.
  signedOut,

  /// No network. Writes are queued and will go out on reconnect.
  offline,

  /// A push/pull round is in flight.
  syncing,

  /// Everything local has reached the server.
  synced,

  /// The last round failed; queued work is retried with backoff.
  error,
}

class SyncStatus {
  const SyncStatus({
    this.state = SyncState.signedOut,
    this.pending = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncState state;

  /// Local changes not yet accepted by the server.
  final int pending;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get isBusy => state == SyncState.syncing;
  bool get hasPending => pending > 0;

  SyncStatus copyWith({
    SyncState? state,
    int? pending,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: clearMessage ? null : (message ?? this.message),
      );

  String get label => switch (state) {
        SyncState.signedOut => 'Local only',
        SyncState.offline =>
          pending > 0 ? 'Offline — $pending pending' : 'Offline',
        SyncState.syncing => 'Syncing…',
        SyncState.synced => pending > 0 ? '$pending pending' : 'Up to date',
        SyncState.error => 'Sync failed',
      };
}
