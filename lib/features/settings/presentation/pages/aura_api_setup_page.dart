import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/ai/data/sources/gemini_chat_source.dart';
import 'package:finora/features/ai/presentation/viewmodels/ai_key_controller.dart';
import 'package:finora/features/ai/presentation/viewmodels/chat_controller.dart';
import 'package:finora/shared/widgets/finora_app_bar.dart';

/// Lets the user supply their own Gemini API key.
///
/// This screen used to be a stub: it showed a success toast and threw the key
/// away, so the assistant always reported "no key configured". Keys now go to
/// the platform keystore via [AiKeyNotifier].
class AuraApiSetupPage extends ConsumerStatefulWidget {
  const AuraApiSetupPage({super.key});

  @override
  ConsumerState<AuraApiSetupPage> createState() => _AuraApiSetupPageState();
}

class _AuraApiSetupPageState extends ConsumerState<AuraApiSetupPage> {
  final _geminiController = TextEditingController();

  bool _isSaving = false;
  bool _obscure = true;
  bool _prefilled = false;

  @override
  void dispose() {
    _geminiController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _save() async {
    final key = _sanitize(_geminiController.text);
    if (key.isEmpty) {
      _toast('Enter a key, or use Remove to clear the saved one.',
          isError: true);
      return;
    }

    // Reflect the cleaned value back, so what is verified is what is shown.
    if (key != _geminiController.text) _geminiController.text = key;

    final shapeProblem = _shapeProblem(key);
    if (shapeProblem != null) {
      _toast(shapeProblem, isError: true);
      return;
    }

    setState(() => _isSaving = true);

    // Verify with a one-token probe before storing, so a typo is caught here
    // rather than surfacing as a mystery failure mid-conversation.
    final result = await ref.read(geminiChatSourceProvider).checkKey(key);

    if (!mounted) return;
    setState(() => _isSaving = false);

    switch (result.outcome) {
      case KeyCheckOutcome.valid:
        await _persist(key, 'API key verified and saved');

      case KeyCheckOutcome.rejected:
        _toast(
          result.message ??
              'That key was rejected. Check it was copied in full and that the '
                  'Generative Language API is enabled.',
          isError: true,
        );

      // Could not reach Google — the key may well be fine, so never claim it
      // was rejected. Offer to store it and verify on first use instead.
      case KeyCheckOutcome.unverified:
        final saveAnyway = await _askSaveAnyway(result.message);
        if (saveAnyway) {
          await _persist(key, 'Key saved without verification');
        }
    }
  }

  Future<void> _persist(String key, String message) async {
    await ref.read(aiKeyProvider.notifier).save(key);
    // Drop the chat state so it re-reads the key and hides the warning banner.
    ref.invalidate(chatControllerProvider);
    if (!mounted) return;
    _toast(message);
    Navigator.pop(context);
  }

  static String _sanitize(String raw) => sanitizeApiKeyForTest(raw);

  String? _shapeProblem(String key) => apiKeyShapeProblemForTest(key);

  Future<bool> _askSaveAnyway(String? reason) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not verify the key'),
        content: Text(
          '${reason ?? 'The AI service could not be reached.'}\n\n'
          'This does not mean the key is wrong — it could not be checked. '
          'Save it anyway and try chatting once you are back online?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _remove() async {
    await ref.read(aiKeyProvider.notifier).clear();
    ref.invalidate(chatControllerProvider);
    _geminiController.clear();
    if (mounted) {
      setState(() {});
      _toast('API key removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyState = ref.watch(aiKeyProvider);

    // Seed the field once with the stored key so it is visible/editable.
    keyState.whenData((value) {
      if (!_prefilled && value.isConfigured) {
        _geminiController.text = value.apiKey ?? '';
        _prefilled = true;
      }
    });

    final isConfigured = keyState.valueOrNull?.isConfigured ?? false;

    return Scaffold(
      appBar: const FinoraAppBar(title: 'AI Assistant Setup'),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            AppSpacing.vMd,
            _StatusCard(
              isConfigured: isConfigured,
              masked: keyState.valueOrNull?.masked ?? '',
            ),
            AppSpacing.vLg,

            Text(
              'Google Gemini API key',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            AppSpacing.vXs,
            Text(
              'The assistant runs on your own key, so you stay in control of '
              'usage and cost. The key is stored in your device keystore and is '
              'never sent anywhere except Google.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            AppSpacing.vMd,
            TextField(
              controller: _geminiController,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'AIzaSy…',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _obscure ? 'Show' : 'Hide',
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    IconButton(
                      tooltip: 'Paste',
                      icon: const Icon(Icons.content_paste_rounded),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        final text = _sanitize(data?.text ?? '');
                        if (text.isNotEmpty) {
                          _geminiController.text = text;
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            AppSpacing.vMd,

            _HowToCard(),
            AppSpacing.vXl,

            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Verifying key…'),
                      ],
                    )
                  : const Text('Verify & Save', style: TextStyle(fontSize: 16)),
            ),
            if (isConfigured) ...[
              AppSpacing.vSm,
              TextButton.icon(
                onPressed: _isSaving ? null : _remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove saved key'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isConfigured, required this.masked});

  final bool isConfigured;
  final String masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConfigured ? AppColors.income : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            isConfigured
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: color,
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConfigured ? 'Key configured' : 'No key configured',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConfigured
                      ? masked
                      : 'The assistant cannot answer until you add a key.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: isConfigured ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const steps = [
      'Open aistudio.google.com/apikey in a browser',
      'Sign in and choose "Create API key"',
      'Copy the key and paste it above',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 18, color: theme.colorScheme.primary),
              AppSpacing.hSm,
              Text(
                'How to get a free key',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppSpacing.vSm,
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(steps[i], style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Cleans up a pasted API key: strips whitespace and newlines the clipboard
/// picks up from a wrapped copy, plus the zero-width characters some browsers
/// insert. Exposed for testing; treat as library-private.
String sanitizeApiKeyForTest(String raw) =>
    raw.replaceAll(RegExp(r'\s'), '').replaceAll(
          RegExp('[​-‍﻿]'),
          '',
        );

/// Rejects only input that is certainly unusable.
///
/// Deliberately does NOT require an `AIza` prefix: Google issues more than one
/// key format, and that assumption rejected a valid AI Studio key before it was
/// ever sent for verification. Google decides whether a key works — anything
/// plausible is passed through to the live check.
///
/// Exposed for testing; treat as library-private.
String? apiKeyShapeProblemForTest(String key) {
  if (key.length < 20) {
    return 'That key looks too short (${key.length} characters). '
        'Copy the whole key from AI Studio.';
  }
  return null;
}
