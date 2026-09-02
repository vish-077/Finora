enum SyncOpType { upsert, delete }

/// A local mutation that still has to reach the server.
///
/// Ops are keyed by `table:rowId`, so repeated edits to the same row collapse
/// into a single pending op instead of replaying an edit history.
class PendingOp {
  const PendingOp({
    required this.table,
    required this.rowId,
    required this.type,
    required this.createdAt,
    this.payload,
    this.retries = 0,
    this.nextAttemptAt,
    this.lastError,
  });

  factory PendingOp.fromMap(Map<String, dynamic> map) => PendingOp(
        table: map['table'] as String,
        rowId: map['row_id'] as String,
        type: (map['type'] as String) == 'delete'
            ? SyncOpType.delete
            : SyncOpType.upsert,
        payload: map['payload'] == null
            ? null
            : Map<String, dynamic>.from(map['payload'] as Map),
        createdAt: DateTime.parse(map['created_at'] as String),
        retries: (map['retries'] as num?)?.toInt() ?? 0,
        nextAttemptAt: map['next_attempt_at'] == null
            ? null
            : DateTime.parse(map['next_attempt_at'] as String),
        lastError: map['last_error'] as String?,
      );

  final String table;
  final String rowId;
  final SyncOpType type;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final int retries;
  final DateTime? nextAttemptAt;
  final String? lastError;

  String get key => '$table:$rowId';

  bool isReady(DateTime now) =>
      nextAttemptAt == null || !nextAttemptAt!.isAfter(now);

  PendingOp copyWith({int? retries, DateTime? nextAttemptAt, String? lastError}) =>
      PendingOp(
        table: table,
        rowId: rowId,
        type: type,
        payload: payload,
        createdAt: createdAt,
        retries: retries ?? this.retries,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'table': table,
        'row_id': rowId,
        'type': type.name,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'retries': retries,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
        'last_error': lastError,
      };
}
