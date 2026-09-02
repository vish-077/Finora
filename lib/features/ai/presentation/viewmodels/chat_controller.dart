import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:finora/core/error/exceptions.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/ai/data/sources/chat_history_source.dart';
import 'package:finora/features/ai/data/sources/gemini_chat_source.dart';
import 'package:finora/features/ai/domain/entities/chat_entities.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_key_controller.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/dashboard_controller.dart';

final chatHistorySourceProvider =
    Provider<ChatHistorySource>((ref) => ChatHistorySource());

final geminiChatSourceProvider =
    Provider<GeminiChatSource>((ref) => GeminiChatSource());

/// Prompts offered on an empty chat. Tapping one sends it immediately.
const List<({String label, String prompt, String icon})> kSuggestedPrompts = [
  (
    label: 'Where is my money going?',
    prompt: 'Based on my spending, which categories take the most and what '
        'should I cut first?',
    icon: 'insights',
  ),
  (
    label: 'How can I save more?',
    prompt: 'Look at my income and expenses and suggest three realistic ways '
        'to save more each month.',
    icon: 'savings',
  ),
  (
    label: 'Am I on budget?',
    prompt: 'Am I on track with my budget this month? Tell me what to watch.',
    icon: 'track',
  ),
  (
    label: 'Set a savings goal',
    prompt: 'Help me set a realistic monthly savings goal based on my income '
        'and current spending.',
    icon: 'flag',
  ),
  (
    label: 'Explain my biggest expense',
    prompt: 'What was my largest expense recently and is that normal for me?',
    icon: 'search',
  ),
];

class ChatState {
  const ChatState({
    required this.conversation,
    required this.history,
    this.isSending = false,
    this.keyConfigured = false,
  });

  /// The thread on screen. May be empty (a fresh "New chat").
  final ChatConversation conversation;

  /// Other saved threads for the history drawer, newest first.
  final List<ChatConversation> history;

  final bool isSending;
  final bool keyConfigured;

  List<ChatMessage> get messages => conversation.messages;
  bool get isEmpty => conversation.isEmpty;

  ChatState copyWith({
    ChatConversation? conversation,
    List<ChatConversation>? history,
    bool? isSending,
    bool? keyConfigured,
  }) =>
      ChatState(
        conversation: conversation ?? this.conversation,
        history: history ?? this.history,
        isSending: isSending ?? this.isSending,
        keyConfigured: keyConfigured ?? this.keyConfigured,
      );
}

class ChatNotifier extends AsyncNotifier<ChatState> {
  static const _uuid = Uuid();

  String get _userId =>
      ref.read(authControllerProvider).user?.id ?? 'local-user';

  ChatHistorySource get _historySource => ref.read(chatHistorySourceProvider);

  @override
  Future<ChatState> build() async {
    final key = await ref.read(aiKeyProvider.notifier).read();
    // Open on a blank thread, ChatGPT-style, with past threads tucked away in
    // the drawer rather than replayed on screen.
    return ChatState(
      conversation: _blankConversation(),
      history: _historySource.conversationsFor(_userId),
      keyConfigured: key != null && key.trim().isNotEmpty,
    );
  }

  ChatConversation _blankConversation() {
    final now = DateTime.now();
    return ChatConversation(
      id: _uuid.v4(),
      userId: _userId,
      title: 'New chat',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatState get _state => state.requireValue;

  /// Starts a fresh thread. The current one is already persisted after each
  /// exchange, so nothing is lost.
  void newChat() {
    state = AsyncData(
      _state.copyWith(
        conversation: _blankConversation(),
        history: _historySource.conversationsFor(_userId),
        isSending: false,
      ),
    );
  }

  void openConversation(String id) {
    final match = _state.history.where((c) => c.id == id).firstOrNull;
    if (match == null) return;
    state = AsyncData(_state.copyWith(conversation: match, isSending: false));
  }

  Future<void> deleteConversation(String id) async {
    await _historySource.delete(id);
    final refreshed = _historySource.conversationsFor(_userId);
    // Deleting the thread you are reading drops you onto a blank one.
    final current = _state.conversation;
    state = AsyncData(
      _state.copyWith(
        history: refreshed,
        conversation: current.id == id ? _blankConversation() : current,
      ),
    );
  }

  Future<void> clearAllHistory() async {
    await _historySource.clearFor(_userId);
    state = AsyncData(
      _state.copyWith(conversation: _blankConversation(), history: const []),
    );
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _state.isSending) return;

    // Read the key fresh rather than trusting a cached flag, so a key added
    // seconds ago in settings is picked up straight away.
    final apiKey = await ref.read(aiKeyProvider.notifier).read();
    final hasKey = apiKey != null && apiKey.trim().isNotEmpty;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: text,
      sentAt: DateTime.now(),
    );

    var convo = _state.conversation;
    convo = convo.copyWith(
      messages: [...convo.messages, userMessage],
      // Name the thread from its first message.
      title: convo.isEmpty ? ChatConversation.titleFrom(text) : convo.title,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(
      _state.copyWith(
        conversation: convo,
        isSending: hasKey,
        keyConfigured: hasKey,
      ),
    );

    if (!hasKey) {
      await _appendAssistant(
        'No API key is configured yet, so I cannot answer.\n\n'
        'Add your own Google Gemini key from the settings icon at the top of '
        'this screen — you can create a free one at aistudio.google.com/apikey. '
        'Your key stays on this device.',
        isError: true,
      );
      return;
    }

    try {
      final reply = await ref.read(geminiChatSourceProvider).send(
            apiKey: apiKey.trim(),
            history: _state.conversation.messages,
            financialContext: _financialContext(),
          );
      await _appendAssistant(reply);
    } on AppException catch (e) {
      await _appendAssistant(e.message, isError: true);
    } catch (e) {
      await _appendAssistant(
        'Something went wrong reaching the assistant. Please try again.',
        isError: true,
      );
    }
  }

  /// Re-sends the last user turn after dropping the failed reply.
  Future<void> retryLast() async {
    final messages = _state.conversation.messages;
    final lastUser = messages.lastWhereOrNullUser();
    if (lastUser == null) return;

    final keep = messages.sublist(0, messages.indexOf(lastUser));
    state = AsyncData(
      _state.copyWith(
        conversation: _state.conversation.copyWith(messages: keep),
      ),
    );
    await send(lastUser.text);
  }

  Future<void> _appendAssistant(String text, {bool isError = false}) async {
    final convo = _state.conversation.copyWith(
      messages: [
        ..._state.conversation.messages,
        ChatMessage(
          id: _uuid.v4(),
          role: ChatRole.assistant,
          text: text,
          sentAt: DateTime.now(),
          isError: isError,
        ),
      ],
      updatedAt: DateTime.now(),
    );

    await _historySource.save(convo);

    state = AsyncData(
      _state.copyWith(
        conversation: convo,
        history: _historySource.conversationsFor(_userId),
        isSending: false,
      ),
    );
  }

  /// A compact snapshot of the user's real numbers, so answers are grounded in
  /// their data instead of generic advice.
  String? _financialContext() {
    final summary = ref.read(dashboardControllerProvider).valueOrNull;
    if (summary == null) return null;

    final buffer = StringBuffer()
      ..writeln('- Total balance: ${summary.totalBalance.formatCurrency()}')
      ..writeln('- Income this month: ${summary.monthlyIncome.formatCurrency()}')
      ..writeln(
          '- Expenses this month: ${summary.monthlyExpense.formatCurrency()}')
      ..writeln('- Total savings: ${summary.savings.formatCurrency()}');

    if (summary.byCategory.isNotEmpty) {
      buffer.writeln('- Top spending categories this month:');
      for (final slice in summary.byCategory.take(6)) {
        buffer.writeln(
            '    · ${slice.categoryName}: ${slice.total.formatCurrency()}');
      }
    }
    return buffer.toString();
  }
}

extension _LastUser on List<ChatMessage> {
  ChatMessage? lastWhereOrNullUser() {
    for (var i = length - 1; i >= 0; i--) {
      if (this[i].isUser) return this[i];
    }
    return null;
  }
}

final chatControllerProvider =
    AsyncNotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
