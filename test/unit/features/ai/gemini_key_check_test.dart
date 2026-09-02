import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finora/features/ai/data/sources/gemini_chat_source.dart';

/// Serves a canned response/error for any request.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.statusCode, this.body, this.throwType});

  final int? statusCode;
  final String? body;
  final DioExceptionType? throwType;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) async {
    if (throwType != null) {
      throw DioException(requestOptions: options, type: throwType!);
    }
    return ResponseBody.fromString(
      body ?? '',
      statusCode!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GeminiChatSource _sourceWith(_StubAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return GeminiChatSource(dio: dio);
}

// Captured verbatim from the live API (invalid key → HTTP 400).
const _invalidKeyBody = '''
{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.",
"status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo",
"reason":"API_KEY_INVALID","domain":"googleapis.com"}]}}
''';

const _okBody = '''
{"candidates":[{"content":{"parts":[{"text":"ok"}],"role":"model"},
"finishReason":"STOP"}]}
''';

void main() {
  group('GeminiChatSource.checkKey', () {
    test('a working key reports valid', () async {
      final source = _sourceWith(_StubAdapter(statusCode: 200, body: _okBody));

      final result = await source.checkKey('AIza${'x' * 35}');

      expect(result.outcome, KeyCheckOutcome.valid);
    });

    // Google returns invalid keys as 400 + API_KEY_INVALID, not 401.
    test('a genuinely invalid key reports rejected', () async {
      final source = _sourceWith(
        _StubAdapter(statusCode: 400, body: _invalidKeyBody),
      );

      final result = await source.checkKey('AIzaBAD');

      expect(result.outcome, KeyCheckOutcome.rejected);
      expect(result.message, contains('API key not valid'));
    });

    // Regression: this used to be reported as "that key was rejected", which
    // sent users hunting for a problem with a key that was perfectly fine.
    test('an offline device reports unverified, never rejected', () async {
      final source = _sourceWith(
        _StubAdapter(throwType: DioExceptionType.connectionError),
      );

      final result = await source.checkKey('AIza${'x' * 35}');

      expect(result.outcome, KeyCheckOutcome.unverified);
      expect(result.outcome, isNot(KeyCheckOutcome.rejected));
    });

    test('a timeout reports unverified', () async {
      final source = _sourceWith(
        _StubAdapter(throwType: DioExceptionType.receiveTimeout),
      );

      expect(
        (await source.checkKey('AIza${'x' * 35}')).outcome,
        KeyCheckOutcome.unverified,
      );
    });

    test('a rate-limited key reports unverified, not rejected', () async {
      final source = _sourceWith(_StubAdapter(
        statusCode: 429,
        body: '{"error":{"code":429,"message":"Quota exceeded"}}',
      ));

      final result = await source.checkKey('AIza${'x' * 35}');

      expect(result.outcome, KeyCheckOutcome.unverified);
      expect(result.message, contains('rate-limited'));
    });

    test('an upstream outage reports unverified', () async {
      final source = _sourceWith(_StubAdapter(
        statusCode: 503,
        body: '{"error":{"code":503,"message":"overloaded"}}',
      ));

      expect(
        (await source.checkKey('AIza${'x' * 35}')).outcome,
        KeyCheckOutcome.unverified,
      );
    });
  });
}
