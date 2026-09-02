import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/utils/extensions/string_extensions.dart';

void main() {
  group('StringX.isGmailAddress', () {
    test('valid @gmail.com returns true', () {
      expect('user@gmail.com'.isGmailAddress, isTrue);
    });

    test('non-gmail returns false', () {
      expect('user@yahoo.com'.isGmailAddress, isFalse);
    });

    test('empty string returns false', () {
      expect(''.isGmailAddress, isFalse);
    });

    test('case-insensitive match', () {
      expect('USER@GMAIL.COM'.isGmailAddress, isTrue);
    });
  });

  group('StringX.initials', () {
    test('two-word name', () => expect('John Doe'.initials, 'JD'));
    test('single word', () => expect('FINORA'.initials, 'F'));
    test('multi-word takes first and last', () => expect('John Michael Doe'.initials, 'JD'));
  });

  group('StringX.truncate', () {
    test('short string unchanged', () => expect('Hi'.truncate(10), 'Hi'));
    test('long string truncated', () => expect('Hello World'.truncate(8), 'Hello W…'));
  });
}
