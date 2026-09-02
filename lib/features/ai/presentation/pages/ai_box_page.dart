import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/ai/domain/entities/chat_entities.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_key_controller.dart';
import 'package:finora/features/ai/presentation/viewmodels/chat_controller.dart';
import 'package:finora/shared/widgets/finora_app_bar.dart';

/// The AI Box: a chat surface with a hidden-by-default history drawer.
class AiBoxPage extends ConsumerStatefulWidget {
  const AiBoxPage({super.key});

  @override
  ConsumerState<AiBoxPage> createState() => _AiBoxPageState();
}

class _AiBoxPageState extends ConsumerState<AiBoxPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _messageController.clear();
    FocusScope.of(context).unfocus();
    _scrollToBottom();
    await ref.read(chatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatControllerProvider);

    return Scaffold(
      key: _scaffoldKey,
      // Hidden by default; opened with the hamburger, exactly like ChatGPT.
      drawer: const _HistoryDrawer(),
      appBar: FinoraAppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Chat history',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        titleWidget: const Text(
          'Finora AI',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: () {
              ref.read(chatControllerProvider.notifier).newChat();
              _messageController.clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI settings',
            onPressed: () => context.push(Routes.aiApiSetup),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Text('Could not open the assistant: $e'),
          ),
        ),
        data: (state) => Column(
          children: [
            if (!state.keyConfigured) const _KeyBanner(),
            Expanded(
              child: state.isEmpty
                  ? _EmptyState(onPromptTap: _send)
                  : _Transcript(
                      state: state,
                      scrollController: _scrollController,
                      onRetry: () =>
                          ref.read(chatControllerProvider.notifier).retryLast(),
                    ),
            ),
            _InputBar(
              controller: _messageController,
              enabled: !state.isSending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── History drawer ──────────────────────────────────────────────────────────

class _HistoryDrawer extends ConsumerWidget {
  const _HistoryDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(chatControllerProvider).valueOrNull;
    final history = state?.history ?? const <ChatConversation>[];
    final currentId = state?.conversation.id;
    final notifier = ref.read(chatControllerProvider.notifier);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary),
                  AppSpacing.hSm,
                  Expanded(
                    child: Text(
                      'Chat history',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (history.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear all history',
                      icon: const Icon(Icons.delete_sweep_outlined),
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Clear all history?',
                          body: 'Every saved conversation on this device will '
                              'be deleted. This cannot be undone.',
                        );
                        if (ok) await notifier.clearAllHistory();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    notifier.newChat();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New chat'),
                ),
              ),
            ),
            AppSpacing.vSm,
            const Divider(height: 1),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 40,
                                color: theme.colorScheme.onSurfaceVariant),
                            AppSpacing.vSm,
                            Text(
                              'No conversations yet',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your chats are saved on this device and stay '
                              'here even after you sign out.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final convo = history[index];
                        final selected = convo.id == currentId;
                        return ListTile(
                          selected: selected,
                          selectedTileColor:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            convo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            _relativeDate(convo.updatedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Delete',
                            onPressed: () => notifier.deleteConversation(convo.id),
                          ),
                          onTap: () {
                            notifier.openConversation(convo.id);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return DateFormat.jm().format(date);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat.EEEE().format(date);
    return DateFormat('d MMM').format(date);
  }
}

// ── Empty state with suggested prompts ──────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  static const Map<String, IconData> _icons = {
    'insights': Icons.insights_rounded,
    'savings': Icons.savings_rounded,
    'track': Icons.track_changes_rounded,
    'flag': Icons.flag_rounded,
    'search': Icons.search_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppSpacing.vXl,
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          ),
        ),
        AppSpacing.vMd,
        Text(
          'How can I help with your money?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        AppSpacing.vXs,
        Text(
          'Pick a question below, or type your own.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        AppSpacing.vXl,
        for (final suggestion in kSuggestedPrompts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPromptTap(suggestion.prompt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        _icons[suggestion.icon] ?? Icons.chat_bubble_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      AppSpacing.hMd,
                      Expanded(
                        child: Text(
                          suggestion.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.north_east_rounded,
                          size: 15, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Transcript ──────────────────────────────────────────────────────────────

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.state,
    required this.scrollController,
    required this.onRetry,
  });

  final ChatState state;
  final ScrollController scrollController;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;

    return ListView.builder(
      controller: scrollController,
      padding: AppSpacing.screenPadding,
      itemCount: messages.length + (state.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) return const _TypingBubble();

        final message = messages[index];
        final isLast = index == messages.length - 1;
        return _Bubble(
          message: message,
          onRetry: message.isError && isLast ? onRetry : null,
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final Color background;
    final Color foreground;
    if (isUser) {
      background = AppColors.primary;
      foreground = Colors.white;
    } else if (message.isError) {
      background = theme.colorScheme.errorContainer;
      foreground = theme.colorScheme.onErrorContainer;
    } else {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = theme.colorScheme.onSurface;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 15, color: foreground),
                        const SizedBox(width: 5),
                        Text(
                          'Could not answer',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: foreground, height: 1.4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(message.sentAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                if (onRetry != null) ...[
                  AppSpacing.hSm,
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            AppSpacing.hSm,
            Text('Thinking…', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ── Key banner ──────────────────────────────────────────────────────────────

class _KeyBanner extends ConsumerWidget {
  const _KeyBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.warning.withValues(alpha: 0.14),
      child: InkWell(
        onTap: () => context.push(Routes.aiApiSetup),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.key_rounded, size: 18, color: AppColors.warning),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  'Add your own Gemini API key to start chatting.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Add key',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input bar ───────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
                onSubmitted: widget.enabled ? widget.onSend : null,
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? 'Ask about your finances…'
                      : 'Waiting for a reply…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
            AppSpacing.hSm,
            _SendButton(
              enabled:
                  widget.enabled && widget.controller.text.trim().isNotEmpty,
              onTap: () => widget.onSend(widget.controller.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.45,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
