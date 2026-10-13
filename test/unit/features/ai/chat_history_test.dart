import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/storage/app_database.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/features/ai/data/sources/chat_history_source.dart';
import 'package:finora/features/ai/domain/entities/chat_entities.dart';

ChatConversation _convo({
  required String id,
  required String userId,
  String title = 'Thread',
  int messages = 2,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime(2026, 1, 1);
  return ChatConversation(
    id: id,
    userId: userId,
    title: title,
    createdAt: now,
    updatedAt: now,
    messages: [
      for (var i = 0; i < messages; i++)
        ChatMessage(
          id: 'm$i',
          role: i.isEven ? ChatRole.user : ChatRole.assistant,
          text: 'message $i',
          sentAt: now,
        ),
    ],
  );
}

void main() {
  late ChatHistorySource source;

  setUpAll(() {
    AppDatabase.initInMemory();
  });

  setUp(() async {
    if (!AppDatabase.isBoxOpen(StorageBoxes.aiHistory)) {
      await AppDatabase.openBox(StorageBoxes.aiHistory);
    }
    await AppDatabase.box(StorageBoxes.aiHistory).clear();
    source = ChatHistorySource();
  });

  group('ChatHistorySource', () {
    test('round-trips a conversation with its messages', () async {
      await source.save(_convo(id: 'a', userId: 'u1', title: 'Budget help'));

      final result = source.conversationsFor('u1');

      expect(result, hasLength(1));
      expect(result.first.title, 'Budget help');
      expect(result.first.messages, hasLength(2));
      expect(result.first.messages.first.role, ChatRole.user);
    });

    test('only returns threads belonging to the given user', () async {
      await source.save(_convo(id: 'a', userId: 'u1'));
      await source.save(_convo(id: 'b', userId: 'u2'));

      expect(source.conversationsFor('u1').map((c) => c.id), ['a']);
      expect(source.conversationsFor('u2').map((c) => c.id), ['b']);
    });

    test('does not persist an empty thread', () async {
      await source.save(_convo(id: 'empty', userId: 'u1', messages: 0));
      expect(source.conversationsFor('u1'), isEmpty);
    });

    test('sorts newest first', () async {
      await source.save(_convo(
          id: 'old', userId: 'u1', updatedAt: DateTime(2026, 1, 1)));
      await source.save(_convo(
          id: 'new', userId: 'u1', updatedAt: DateTime(2026, 6, 1)));

      expect(source.conversationsFor('u1').map((c) => c.id), ['new', 'old']);
    });

    test('delete removes only the targeted thread', () async {
      await source.save(_convo(id: 'a', userId: 'u1'));
      await source.save(_convo(id: 'b', userId: 'u1'));

      await source.delete('a');

      expect(source.conversationsFor('u1').map((c) => c.id), ['b']);
    });

    test('clearFor wipes one user and leaves the other intact', () async {
      await source.save(_convo(id: 'a', userId: 'u1'));
      await source.save(_convo(id: 'b', userId: 'u2'));

      await source.clearFor('u1');

      expect(source.conversationsFor('u1'), isEmpty);
      expect(source.conversationsFor('u2'), hasLength(1));
    });

    test('survives a simulated sign-out that clears other boxes', () async {
      await source.save(_convo(id: 'a', userId: 'u1'));

      // Sign-out clears the data boxes but must leave aiHistory alone, so the
      // user's conversations are still there when they sign back in.
      for (final name in [
        StorageBoxes.transactions,
        StorageBoxes.categories,
        StorageBoxes.budgets,
      ]) {
        if (!AppDatabase.isBoxOpen(name)) await AppDatabase.openBox(name);
        await AppDatabase.box(name).clear();
      }

      expect(source.conversationsFor('u1'), hasLength(1));
    });

    test('skips unreadable entries instead of throwing', () async {
      await AppDatabase.box(StorageBoxes.aiHistory).put('chat_bad', 'not-a-map');
      await source.save(_convo(id: 'good', userId: 'u1'));

      expect(source.conversationsFor('u1').map((c) => c.id), ['good']);
    });
  });

  group('ChatConversation.titleFrom', () {
    test('uses the message text', () {
      expect(ChatConversation.titleFrom('How do I save more?'),
          'How do I save more?');
    });

    test('collapses whitespace', () {
      expect(ChatConversation.titleFrom('  a   b  '), 'a b');
    });

    test('truncates a long message', () {
      final title = ChatConversation.titleFrom('x' * 100);
      expect(title.length, lessThanOrEqualTo(39));
      expect(title, endsWith('…'));
    });

    test('falls back for blank input', () {
      expect(ChatConversation.titleFrom('   '), 'New chat');
    });
  });
}
