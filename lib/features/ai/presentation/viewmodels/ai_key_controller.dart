import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finora/core/security/secure_key_service.dart';

/// Whether the user has supplied their own AI API key, and what it is.
///
/// Previously the setup screen only showed a success toast and never wrote
/// anything, so the assistant always believed no key was configured. This is
/// the single source of truth both screens read.
class AiKeyState {
  const AiKeyState({this.apiKey, this.loading = true});

  final String? apiKey;
  final bool loading;

  bool get isConfigured => (apiKey?.trim().isNotEmpty ?? false);

  /// Key with the middle masked, for display.
  String get masked {
    final key = apiKey?.trim() ?? '';
    if (key.isEmpty) return '';
    if (key.length <= 10) return '${key[0]}${'•' * (key.length - 1)}';
    return '${key.substring(0, 6)}${'•' * 8}${key.substring(key.length - 4)}';
  }
}

class AiKeyNotifier extends AsyncNotifier<AiKeyState> {
  @override
  Future<AiKeyState> build() async {
    final key = await SecureKeyService.readAiApiKey();
    return AiKeyState(apiKey: key, loading: false);
  }

  /// Persists [apiKey] to the platform keystore. Passing blank clears it.
  Future<void> save(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clear();
      return;
    }
    await SecureKeyService.saveAiApiKey(trimmed);
    state = AsyncData(AiKeyState(apiKey: trimmed, loading: false));
  }

  Future<void> clear() async {
    await SecureKeyService.clearAiApiKey();
    state = const AsyncData(AiKeyState(apiKey: null, loading: false));
  }

  /// Reads straight from secure storage — used on the send path so a key saved
  /// moments earlier is never missed because of a stale provider snapshot.
  Future<String?> read() => SecureKeyService.readAiApiKey();
}

final aiKeyProvider = AsyncNotifierProvider<AiKeyNotifier, AiKeyState>(
  AiKeyNotifier.new,
);
