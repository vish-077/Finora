class HiveBoxes {
  HiveBoxes._();

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
}

class HiveTypeIds {
  HiveTypeIds._();

  // ── Range 0–9: Core entities ──────────────────────────────────────────────
  static const int userProfileModel = 0;
  static const int transactionModel = 1;
  static const int categoryModel = 2;
  static const int budgetModel = 3;
  static const int walletModel = 4;
  static const int goalModel = 5;
  static const int syncQueueItemModel = 6;
  static const int aiMessageModel = 7;
  static const int settingsModel = 8;
  static const int notificationModel = 9;

  // ── Range 10–19: Supporting models ────────────────────────────────────────
  static const int receiptModel = 10;
  static const int reportModel = 11;

  // ── Range 20–29: Enums ────────────────────────────────────────────────────
  static const int transactionTypeAdapter = 20;
  static const int walletTypeAdapter = 21;
  static const int syncOperationAdapter = 22;
  static const int themePreferenceAdapter = 23;
}
