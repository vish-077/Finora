import 'package:flutter_test/flutter_test.dart';

import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  group('auth network error mapping', () {
    // Regression: a dead/unreachable backend host surfaced the raw
    // "ClientException with SocketException: Failed host lookup ..." string
    // straight into a red box on the register screen.
    test('DNS failure maps to an actionable message, not the raw exception', () {
      final failure = mapAuthTransportErrorForTest(
        'ClientException with SocketException: Failed host lookup: '
        "'backend.example.com' (OS Error: No address associated "
        'with hostname, errno = 7)',
        null,
      );

      expect(failure, isA<ServerFailure>());
      expect(failure!.code, 'HOST_UNREACHABLE');
      expect(failure.message, isNot(contains('SocketException')));
      expect(failure.message, isNot(contains('errno')));
      expect(failure.message.toLowerCase(), contains('cannot reach'));
    });

    test('generic socket error maps to no-internet', () {
      final failure = mapAuthTransportErrorForTest(
        'ClientException: Connection refused',
        null,
      );
      expect(failure, isA<NoInternetFailure>());
    });

    test('timeout maps to timeout failure', () {
      final failure = mapAuthTransportErrorForTest('Request timed out', null);
      expect(failure, isA<TimeoutFailure>());
    });

    test('a real auth error is left alone', () {
      expect(
        mapAuthTransportErrorForTest('Invalid login credentials', null),
        isNull,
      );
    });
  });
}
