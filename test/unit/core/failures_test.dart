import 'package:flutter_test/flutter_test.dart';
import 'package:finora/core/error/failures.dart';

void main() {
  group('Failure sealed class', () {
    test('LocalFailure equality', () {
      const a = LocalFailure('db error', code: 'HIVE_READ');
      const b = LocalFailure('db error', code: 'HIVE_READ');
      expect(a, equals(b));
    });

    test('different subtypes are not equal', () {
      const a = LocalFailure('error');
      const b = NetworkFailure('error');
      expect(a, isNot(equals(b)));
    });

    test('ServerFailure carries statusCode', () {
      const failure = ServerFailure('Not Found', statusCode: 404);
      expect(failure.statusCode, 404);
      expect(failure.code, isNull);
    });

    test('PinLockedFailure message includes minutes', () {
      const failure = PinLockedFailure(15);
      expect(failure.message, contains('15'));
    });

    test('InvalidEmailDomainFailure has correct code', () {
      const failure = InvalidEmailDomainFailure();
      expect(failure.code, 'INVALID_EMAIL_DOMAIN');
    });
  });
}
