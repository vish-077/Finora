import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rejects empty', () => expect(Validators.email(''), isNotNull));
    test('rejects malformed',
        () => expect(Validators.email('not-an-email'), isNotNull));
    test('accepts valid', () => expect(Validators.email('a@b.com'), isNull));
  });

  group('Validators.gmail', () {
    test('rejects non-gmail',
        () => expect(Validators.gmail('a@yahoo.com'), isNotNull));
    test('accepts gmail', () => expect(Validators.gmail('a@gmail.com'), isNull));
  });

  group('Validators.password', () {
    test('rejects short', () => expect(Validators.password('Ab1'), isNotNull));
    test('requires uppercase',
        () => expect(Validators.password('lowercase1'), isNotNull));
    test('requires number',
        () => expect(Validators.password('NoNumbersHere'), isNotNull));
    test('accepts strong',
        () => expect(Validators.password('Str0ngPass'), isNull));
  });

  group('Validators.confirmPassword', () {
    test('rejects mismatch',
        () => expect(Validators.confirmPassword('a', 'b'), isNotNull));
    test('accepts match',
        () => expect(Validators.confirmPassword('same', 'same'), isNull));
  });

  group('Validators.displayName', () {
    test('rejects empty', () => expect(Validators.displayName(''), isNotNull));
    test('rejects single char',
        () => expect(Validators.displayName('A'), isNotNull));
    test('accepts valid', () => expect(Validators.displayName('Jane'), isNull));
  });

  group('Validators.passwordStrength', () {
    test('weak password scores low',
        () => expect(Validators.passwordStrength('abc'), lessThanOrEqualTo(1)));
    test('strong password scores high',
        () => expect(Validators.passwordStrength(r'Str0ng!Pass'), 4));
  });
}
