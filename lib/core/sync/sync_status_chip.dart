import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finora/core/sync/sync_providers.dart';
import 'package:finora/core/sync/sync_status.dart';

/// Small always-visible indicator of whether this device is up to date with
/// the account. Tapping it forces a round.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(syncEngineProvider);
    final status = ref.watch(syncStatusProvider).valueOrNull ??
        engine?.status ??
        const SyncStatus();

    if (status.state == SyncState.signedOut) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (status.state) {
      SyncState.syncing => (Icons.sync_rounded, scheme.primary),
      SyncState.offline => (Icons.cloud_off_rounded, scheme.outline),
      SyncState.error => (Icons.sync_problem_rounded, scheme.error),
      SyncState.synced when status.hasPending => (
          Icons.cloud_upload_rounded,
          scheme.tertiary
        ),
      SyncState.synced => (Icons.cloud_done_rounded, scheme.primary),
      SyncState.signedOut => (Icons.cloud_off_rounded, scheme.outline),
    };

    return Tooltip(
      message: status.label,
      child: IconButton(
        icon: status.isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, color: color, size: 20),
        onPressed: status.isBusy ? null : () => requestManualSync(ref),
      ),
    );
  }
}
