import 'package:finora/core/constants/storage_constants.dart';

/// Pairs a Firestore collection with the SQLite box that mirrors it.
///
/// In the cloud each row lives at `users/{uid}/{remote}/{id}`. Every mirrored
/// box uses the same local convention: key = row id,
/// value = `jsonEncode(rowMap)`. That lets the sync engine merge rows
/// generically, without knowing anything about the feature's model classes.
class SyncTable {
  const SyncTable({required this.remote, required this.box});

  /// Firestore sub-collection name (under `users/{uid}`).
  final String remote;

  /// Local box name that caches it.
  final String box;

  @override
  String toString() => remote;
}

class SyncTables {
  SyncTables._();

  /// Top-level Firestore collection that holds one document per account.
  static const String userRoot = 'users';

  static const SyncTable categories =
      SyncTable(remote: 'categories', box: StorageBoxes.categories);
  static const SyncTable accounts =
      SyncTable(remote: 'accounts', box: StorageBoxes.wallets);
  static const SyncTable budgets =
      SyncTable(remote: 'budgets', box: StorageBoxes.budgets);
  static const SyncTable expenses =
      SyncTable(remote: 'expenses', box: StorageBoxes.transactions);

  /// Push/pull order. Parents first so a child row never reaches the server
  /// before the row it references.
  static const List<SyncTable> all = <SyncTable>[
    categories,
    accounts,
    budgets,
    expenses,
  ];

  static SyncTable? byRemote(String name) {
    for (final t in all) {
      if (t.remote == name) return t;
    }
    return null;
  }
}
