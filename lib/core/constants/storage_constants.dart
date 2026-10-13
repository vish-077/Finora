/// Names of the SQLite-backed key/value boxes (see `AppDatabase`).
class StorageBoxes {
  StorageBoxes._();

  static const String userProfile = 'finora_user_profile';
  static const String transactions = 'finora_transactions';
  static const String categories = 'finora_categories';
  static const String budgets = 'finora_budgets';
  static const String wallets = 'finora_wallets';
  static const String goals = 'finora_goals';
  static const String syncQueue = 'finora_sync_queue';

  /// Which account the mirrored boxes currently belong to, plus the stashed
  /// copies of every other owner's data. Owned by `SyncScopeStore`.
  static const String syncScope = 'finora_sync_scope';
  static const String aiHistory = 'finora_ai_history';
  static const String settings = 'finora_settings';
  static const String notifications = 'finora_notifications';
  static const String receipts = 'finora_receipts';
  static const String reports = 'finora_reports';

  static const List<String> all = <String>[
    userProfile,
    transactions,
    categories,
    budgets,
    wallets,
    goals,
    syncQueue,
    syncScope,
    aiHistory,
    settings,
    notifications,
    receipts,
    reports,
  ];
}
