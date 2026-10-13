import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/logging/log_service.dart';
import 'package:finora/features/ai/domain/entities/chat_entities.dart';

/// Local, per-user chat history.
///
/// Threads live in the `aiHistory` box keyed by conversation id and are
/// deliberately *not* wiped on sign-out, so a user who logs back in still has
/// their conversations. Filtering by `userId` keeps one account's threads out
/// of another's list on a shared device.
class ChatHistorySource {
  static const String _prefix = 'chat_';

  SqlBox? get _box {
    try {
      return AppDatabase.box(StorageBoxes.aiHistory);
    } catch (_) {
      // Box not open (widget tests, early boot) — behave as empty history.
      return null;
    }
  }

  /// All conversations for [userId], newest first, skipping empty threads.
  List<ChatConversation> conversationsFor(String userId) {
    final box = _box;
    if (box == null) return [];

    final result = <ChatConversation>[];
    for (final key in box.keys) {
      if (!key.startsWith(_prefix)) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      try {
        final convo = ChatConversation.fromJson(raw);
        if (convo.userId != userId || convo.isEmpty) continue;
        result.add(convo);
      } catch (e) {
        LogService.w('Skipping unreadable chat thread $key: $e');
      }
    }

    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<void> save(ChatConversation conversation) async {
    // An untouched "New chat" is not worth a history entry.
    if (conversation.isEmpty) return;
    await _box?.put('$_prefix${conversation.id}', conversation.toJson());
  }

  Future<void> delete(String conversationId) =>
      _box?.delete('$_prefix$conversationId') ?? Future.value();

  Future<void> clearFor(String userId) async {
    final box = _box;
    if (box == null) return;
    final keys = conversationsFor(userId).map((c) => '$_prefix${c.id}').toList();
    await box.deleteAll(keys);
  }
}
