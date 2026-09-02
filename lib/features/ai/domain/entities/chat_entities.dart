import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.sentAt,
    this.isError = false,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime sentAt;

  /// Assistant messages that represent a failure. Kept in the transcript so
  /// the user can see what happened, but never sent back as context.
  final bool isError;

  bool get isUser => role == ChatRole.user;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'sentAt': sentAt.toIso8601String(),
        'isError': isError,
      };

  static ChatMessage fromJson(Map<dynamic, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: (json['role'] as String? ?? 'assistant') == 'user'
            ? ChatRole.user
            : ChatRole.assistant,
        text: json['text'] as String? ?? '',
        sentAt:
            DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
        isError: json['isError'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, role, text, sentAt, isError];
}

/// One conversation thread.
class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Owner. History is stored per user so logging out and back in restores
  /// your own threads without exposing them to a different account.
  final String userId;

  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => messages.isEmpty;

  /// First user message, trimmed — used as the thread title in the history
  /// drawer, the same way ChatGPT names a new chat.
  static String titleFrom(String firstMessage) {
    final clean = firstMessage.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'New chat';
    return clean.length <= 38 ? clean : '${clean.substring(0, 38)}…';
  }

  ChatConversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) =>
      ChatConversation(
        id: id,
        userId: userId,
        title: title ?? this.title,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  static ChatConversation fromJson(Map<dynamic, dynamic> json) {
    final rawMessages = (json['messages'] as List<dynamic>? ?? []);
    return ChatConversation(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? 'local-user',
      title: json['title'] as String? ?? 'New chat',
      messages: rawMessages
          .whereType<Map<dynamic, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, userId, title, messages, createdAt, updatedAt];
}
