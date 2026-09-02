import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/core/network/network_info.dart';

/// Emits the current online/offline state (seeded, then live updates).
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final net = sl<NetworkInfo>();
  yield await net.isConnected;
  yield* net.onConnectivityChanged;
});

/// A slim banner that appears only while the device is offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();

    return Material(
      color: Colors.orange.shade800,
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                "You're offline — changes will sync when reconnected",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
