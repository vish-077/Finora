import 'package:dio/dio.dart';

import 'package:finora/core/config/app_config.dart';
import 'package:finora/core/error/exceptions.dart';
import 'package:finora/core/logging/log_service.dart';
import 'package:finora/features/ai/domain/entities/chat_entities.dart';

/// Talks to Google Gemini with the key the user supplied.
///
/// Nothing is sent unless the user has configured a key of their own; there is
/// no bundled fallback key.
class GeminiChatSource {
  GeminiChatSource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
            ));

  final Dio _dio;

  static const String model = 'gemini-2.0-flash';

  /// Trimmed context window. Sending the whole transcript grows cost without
  /// improving answers much, so only the recent turns go along.
  static const int _historyTurns = 12;

  /// Sends [history] (already including the newest user turn) and returns the
  /// assistant's reply text.
  Future<String> send({
    required String apiKey,
    required List<ChatMessage> history,
    String? financialContext,
  }) async {
    final recent = history.where((m) => !m.isError).toList();
    final trimmed = recent.length <= _historyTurns
        ? recent
        : recent.sublist(recent.length - _historyTurns);

    final url = '${AppConfig.geminiApiBaseUrl}/models/$model:generateContent';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        url,
        // The key goes in a header, not the query string, so it cannot end up
        // in logs or proxy access records.
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt(financialContext)},
            ],
          },
          'contents': [
            for (final m in trimmed)
              {
                'role': m.isUser ? 'user' : 'model',
                'parts': [
                  {'text': m.text},
                ],
              },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 800,
          },
        },
      );

      final text = _extractText(response.data);
      if (text == null || text.trim().isEmpty) {
        throw const AIException(
          'The assistant returned an empty response. Please try again.',
        );
      }
      return text.trim();
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  String _systemPrompt(String? financialContext) {
    final base = StringBuffer(
      'You are Finora, a concise and practical personal-finance assistant '
      'inside an expense-tracking app. Give specific, actionable answers about '
      'budgeting, spending patterns, saving and expense categorisation. '
      'Keep replies under 150 words unless asked for detail. Use plain text, '
      'short paragraphs and simple dashes for lists — no markdown headings or '
      'asterisks. Never invent figures: if you lack the data, say so and '
      'explain what the user should record.',
    );
    if (financialContext != null && financialContext.trim().isNotEmpty) {
      base.write(
        "\n\nHere is a snapshot of the user's current finances. Use it when "
        'relevant:\n$financialContext',
      );
    }
    return base.toString();
  }

  String? _extractText(Map<String, dynamic>? body) {
    if (body == null) return null;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;

    // A safety block returns a candidate with no parts.
    final finishReason = first['finishReason'];
    final content = first['content'];
    if (content is! Map) {
      if (finishReason == 'SAFETY') {
        return "I can't help with that particular request. Try asking about "
            'your budgets, spending or savings.';
      }
      return null;
    }

    final parts = content['parts'];
    if (parts is! List) return null;

    return parts
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join();
  }

  AppException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    // Gemini puts a human-readable reason in error.message, and a machine
    // reason in error.details[].reason (e.g. API_KEY_INVALID).
    String? apiMessage;
    String? apiReason;
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        apiMessage = error['message'] as String?;
        final details = error['details'];
        if (details is List) {
          for (final d in details.whereType<Map>()) {
            final reason = d['reason'];
            if (reason is String && reason.isNotEmpty) {
              apiReason = reason;
              break;
            }
          }
        }
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkException(
        'The assistant took too long to respond. Please try again.',
        code: 'TIMEOUT',
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return const NetworkException(
        'No internet connection. The AI assistant needs to be online.',
        code: 'NO_INTERNET',
      );
    }

    // An invalid key comes back as 400 + API_KEY_INVALID, not 401, so it has
    // to be detected here rather than by status code alone.
    final looksLikeKeyProblem = apiReason == 'API_KEY_INVALID' ||
        apiReason == 'API_KEY_SERVICE_BLOCKED' ||
        (apiMessage?.toLowerCase().contains('api key not valid') ?? false) ||
        (apiMessage?.toLowerCase().contains('api key expired') ?? false);

    switch (status) {
      case 400:
        if (looksLikeKeyProblem) {
          return AIException(
            apiMessage ??
                'That API key is not valid. Check it was copied in full.',
            code: 'INVALID_KEY',
          );
        }
        return AIException(
          'The assistant rejected the request. ${apiMessage ?? ''}'.trim(),
          code: 'BAD_REQUEST',
        );
      case 401:
      case 403:
        return AIException(
          looksLikeKeyProblem
              ? apiMessage!
              : 'Your API key is invalid or lacks access to the Generative '
                  'Language API. Re-check it in AI settings.',
          code: 'INVALID_KEY',
        );
      case 404:
        return const AIException(
          'The AI model is unavailable for this key. Make sure the Generative '
          'Language API is enabled for your Google project.',
          code: 'MODEL_NOT_FOUND',
        );
      case 429:
        return const AIException(
          'You have hit your API rate limit. Wait a moment and try again.',
          code: 'RATE_LIMIT',
        );
      case 500:
      case 502:
      case 503:
        return const AIException(
          'The AI service is temporarily unavailable. Try again shortly.',
          code: 'UPSTREAM',
        );
    }

    LogService.e('Gemini request failed', error: e);
    return AIException(
      apiMessage ?? 'Could not reach the AI service. Please try again.',
      code: 'UNKNOWN',
    );
  }

  /// Cheap validity probe used by the settings screen when saving a key.
  ///
  /// Three-way on purpose. An earlier version returned a plain bool, which
  /// meant an offline device or a rate-limited quota was reported to the user
  /// as "that key was rejected" — actively misleading, since the key may be
  /// perfectly fine and simply unverifiable right now.
  Future<KeyCheckResult> checkKey(String apiKey) async {
    try {
      // Metadata endpoint, NOT generateContent. Verifying used to spend a real
      // generation call, so on a fresh free-tier key a couple of attempts were
      // enough to trip the per-minute limit and the check reported a rate-limit
      // error for a perfectly good key. ListModels authenticates the key the
      // same way (invalid keys still return 400/API_KEY_INVALID) without
      // touching the generation quota.
      await _dio.get<Map<String, dynamic>>(
        '${AppConfig.geminiApiBaseUrl}/models',
        options: Options(headers: {'x-goog-api-key': apiKey}),
      );
      return const KeyCheckResult(KeyCheckOutcome.valid);
    } on DioException catch (e) {
      return _outcomeFor(_mapDioError(e));
    } on AppException catch (e) {
      return _outcomeFor(e);
    }
  }

  KeyCheckResult _outcomeFor(AppException e) {
    switch (e.code) {
      // The only case where Google actually refused the credential.
      case 'INVALID_KEY':
        return KeyCheckResult(KeyCheckOutcome.rejected, e.message);

      // A quota response proves the key authenticated — it is real, the check
      // just could not finish. Never report this as a rejection.
      case 'RATE_LIMIT':
        return const KeyCheckResult(
          KeyCheckOutcome.unverified,
          'Google rate-limited the check before it finished. The key is '
          'almost certainly fine — save it and try chatting in a minute.',
        );

      default:
        return KeyCheckResult(KeyCheckOutcome.unverified, e.message);
    }
  }
}

enum KeyCheckOutcome {
  /// Probe succeeded — the key works.
  valid,

  /// Google explicitly refused the key.
  rejected,

  /// Could not tell (offline, timeout, upstream outage, quota).
  unverified,
}

class KeyCheckResult {
  const KeyCheckResult(this.outcome, [this.message]);

  final KeyCheckOutcome outcome;
  final String? message;
}
