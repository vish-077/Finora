import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:finora/core/error/exceptions.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/network/network_info.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';
import 'package:finora/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finora/features/auth/data/sources/auth_local_source.dart';
import 'package:finora/features/auth/data/sources/auth_remote_source.dart';

class MockRemote extends Mock implements AuthRemoteSource {}

class MockLocal extends Mock implements AuthLocalSource {}

class MockNetwork extends Mock implements NetworkInfo {}

void main() {
  late MockRemote remote;
  late MockLocal local;
  late MockNetwork network;
  late AuthRepositoryImpl repo;

  const tUser = AuthUserModel(
    id: 'u1',
    email: 'jane@gmail.com',
    displayName: 'Jane',
    isEmailVerified: true,
  );

  setUpAll(() => registerFallbackValue(tUser));

  setUp(() {
    remote = MockRemote();
    local = MockLocal();
    network = MockNetwork();
    repo = AuthRepositoryImpl(remote: remote, local: local, network: network);

    when(() => network.isConnected).thenAnswer((_) async => true);
    when(() => local.saveSession(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => local.cacheUser(any())).thenAnswer((_) async {});
    when(() => local.clearSession()).thenAnswer((_) async {});
    when(() => local.clearCachedUser()).thenAnswer((_) async {});
    when(() => local.clearAllUserData()).thenAnswer((_) async {});
    when(() => local.saveRegisteredUser(any())).thenAnswer((_) async {});
    when(() => local.readRegisteredUser(any())).thenReturn(null);
    when(() => local.readAccessToken()).thenAnswer((_) async => null);
    when(() => local.readRefreshToken()).thenAnswer((_) async => null);
    when(() => local.setBiometricEnabled(enabled: any(named: 'enabled')))
        .thenAnswer((_) async {});
  });

  group('signIn', () {
    test('returns AuthSession and persists on success', () async {
      const session = RemoteSession(accessToken: 'access', refreshToken: 'refresh');
      when(() => remote.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              ))
          .thenAnswer((_) async => (user: tUser, session: session));

      final result = await repo.signIn(
          email: 'jane@gmail.com', password: 'Str0ngPass');

      expect(result.isRight(), isTrue);
      verify(() => local.saveSession(
          accessToken: 'access', refreshToken: 'refresh')).called(1);
      verify(() => local.cacheUser(any())).called(1);
    });

    test('falls back to registered user if remote sign-in throws exception', () async {
      when(() => remote.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              ))
          .thenThrow(const AuthException('Invalid login credentials', code: 'invalid_credentials'));
      when(() => local.readRegisteredUser('jane@gmail.com')).thenReturn(tUser);

      final result = await repo.signIn(email: 'jane@gmail.com', password: 'Str0ngPass');

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => throw Exception()).user.email, 'jane@gmail.com');
    });

    test('maps invalid credentials to InvalidCredentialsFailure if not registered locally', () async {
      when(() => remote.signIn(
                email: any(named: 'email'),
                password: any(named: 'password'),
              ))
          .thenThrow(const AuthException('Invalid login credentials',
              code: 'invalid_credentials'));

      final result = await repo.signIn(email: 'a@b.com', password: 'x');

      expect(
        result.getLeft().toNullable(),
        isA<InvalidCredentialsFailure>(),
      );
    });

    test('returns NoInternetFailure when offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repo.signIn(email: 'a@b.com', password: 'x');

      expect(result.getLeft().toNullable(), isA<NoInternetFailure>());
    });
  });

  group('signUp', () {
    test('returns user on success', () async {
      when(() => remote.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async => (user: tUser, session: null));

      final result = await repo.signUp(
          email: 'jane@gmail.com', password: 'Str0ngPass', displayName: 'Jane');

      expect(result.isRight(), isTrue);
      verify(() => local.cacheUser(any())).called(1);
    });

    test('maps existing user error', () async {
      when(() => remote.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
          )).thenThrow(const AuthException('User already registered',
          code: 'user_already_exists'));

      final result = await repo.signUp(
          email: 'a@b.com', password: 'x', displayName: 'A');

      final failure = result.getLeft().toNullable();
      expect(failure, isA<AuthFailure>());
      expect(failure?.code, 'USER_EXISTS');
    });
  });

  group('signOut', () {
    test('clears local session, cache and biometric flag', () async {
      when(() => remote.signOut()).thenAnswer((_) async {});

      final result = await repo.signOut();

      expect(result, equals(right<Failure, Unit>(unit)));
      verify(() => local.clearSession()).called(1);
      verify(() => local.clearCachedUser()).called(1);
      verify(() => local.clearAllUserData()).called(1);
      verify(() => local.setBiometricEnabled(enabled: false)).called(1);
    });

    test('still clears local even if remote sign-out fails', () async {
      when(() => remote.signOut())
          .thenThrow(const AuthException('boom', code: 'x'));

      final result = await repo.signOut();

      expect(result.isRight(), isTrue);
      verify(() => local.clearSession()).called(1);
      verify(() => local.clearCachedUser()).called(1);
      verify(() => local.clearAllUserData()).called(1);
    });
  });

  group('biometric', () {
    test('delegates isBiometricEnabled to local', () async {
      when(() => local.isBiometricEnabled()).thenAnswer((_) async => true);
      expect(await repo.isBiometricEnabled(), isTrue);
    });
  });
}
