import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:finora/core/sync/sync_engine.dart';
import 'package:finora/core/sync/sync_status.dart';

final Provider<SyncEngine?> syncEngineProvider = Provider<SyncEngine?>((ref) {
  final sl = GetIt.instance;
  return sl.isRegistered<SyncEngine>() ? sl<SyncEngine>() : null;
});

/// Live sync state for the UI. Seeded with the engine's current value so a
/// widget built between rounds still renders something meaningful.
final StreamProvider<SyncStatus> syncStatusProvider =
    StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return const Stream<SyncStatus>.empty();
  return engine.statusStream;
});

/// Manual "sync now", for pull-to-refresh and the status chip.
Future<void> requestManualSync(WidgetRef ref) async {
  final engine = ref.read(syncEngineProvider);
  await engine?.syncNow(reason: 'manual');
}
