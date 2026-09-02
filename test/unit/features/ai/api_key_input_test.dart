import 'package:flutter_test/flutter_test.dart';

import 'package:finora/features/settings/presentation/pages/aura_api_setup_page.dart';

void main() {
  group('API key sanitising', () {
    test('strips surrounding whitespace and newlines from a paste', () {
      expect(sanitizeApiKeyForTest('  AIzaSyABC123  \n'), 'AIzaSyABC123');
    });

    test('strips internal line breaks a wrapped copy introduces', () {
      expect(sanitizeApiKeyForTest('AIzaSy\nABC\r\n123'), 'AIzaSyABC123');
    });

    test('strips zero-width characters some browsers add', () {
      expect(sanitizeApiKeyForTest('AIza​Sy﻿ABC'), 'AIzaSyABC');
    });

    test('leaves a clean key untouched', () {
      const key = 'AIzaSyC7Xk92mQpLv3nR8tZ4bW1yH6dF0sJ5aKe';
      expect(sanitizeApiKeyForTest(key), key);
    });
  });

  group('API key shape check', () {
    // Regression: this used to require an "AIza" prefix, which rejected a
    // valid AI Studio key before it was ever sent to Google. Google is the
    // authority on validity — only clearly unusable input is refused locally.
    test('accepts a key that does not start with AIza', () {
      expect(apiKeyShapeProblemForTest('ya29.averyLongTokenValueHere12345'),
          isNull);
    });

    test('accepts a standard AIza key', () {
      expect(
        apiKeyShapeProblemForTest('AIzaSyC7Xk92mQpLv3nR8tZ4bW1yH6dF0sJ5aKe'),
        isNull,
      );
    });

    test('rejects an obviously truncated key and says how short it is', () {
      final problem = apiKeyShapeProblemForTest('AIzaSy123');
      expect(problem, isNotNull);
      expect(problem, contains('9 characters'));
    });
  });
}
