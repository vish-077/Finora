import 'package:finora/core/constants/hive_constants.dart';

/// Pairs a Postgres table with the Hive box that mirrors it.
///
/// Every mirrored box uses the same convention: key = row id,
/// value = `jsonEncode(rowMap)`. That lets the sync engine merge rows
/// generically, without knowing anything about the feature's model classes.
class SyncTable {
  const SyncTable({required this.remote, required this.box});

  /// Postgres table name.
  final String remote;

  /// Hive box name that caches it.
  final String box;

  @override
  String toString() => remote;
}

class SyncTables {
  SyncTables._();

  static const SyncTable categories =
      SyncTable(remote: 'categories', box: HiveBoxes.categories);
  static const SyncTable accounts =
      SyncTable(remote: 'accounts', box: HiveBoxes.wallets);
  static const SyncTable budgets =
      SyncTable(remote: 'budgets', box: HiveBoxes.budgets);
  static const SyncTable expenses =
      SyncTable(remote: 'expenses', box: HiveBoxes.transactions);

  /// Push/pull order. Parents first so a child row never hits the server
  /// before the row its foreign key points at.
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
